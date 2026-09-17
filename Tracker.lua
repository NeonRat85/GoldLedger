--[[
    GoldLedger: Tracker.lua
    Patterns: Observer, State

    Отслеживает изменения голды через WoW-ивенты:
    - PLAYER_LOGIN → запоминает начальный баланс
    - PLAYER_MONEY → вычисляет дельту, логирует через Data
    - Контекстные ивенты → определяет источник (вендор, АХ, почта и т.д.)
    - Callback система для уведомления UI об изменениях
]]

local ADDON_NAME, ns = ...
local GoldLedger = ns.GoldLedger
local L = ns.L

local Tracker = {}
GoldLedger:RegisterModule("Tracker", Tracker)

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local lastGold = 0          -- Последнее известное количество голды (copper)
local isReady = false       -- Готов ли трекер (после PLAYER_LOGIN)
local sessionIncome = 0     -- Доход за текущую сессию (copper)
local sessionExpense = 0    -- Расход за текущую сессию (copper)
local repairPending = false -- Флаг: была вызвана RepairAllItems()

-- FIFO of mail snapshots captured by the TakeInboxMoney hook. Each PLAYER_MONEY
-- at the mailbox consumes one entry — that lets us attribute income to the
-- specific mail the player just opened (instead of guessing from inbox state).
local pendingMailQueue = {}

-- Bank money moves captured by hooks on C_Bank.DepositMoney/WithdrawMoney and
-- the guild bank equivalents. Each is matched to the PLAYER_MONEY that follows
-- by exact amount and direction; stale entries expire after BANK_OP_TIMEOUT.
local pendingBankOps = {}
local BANK_OP_TIMEOUT = 10

-------------------------------------------------------------------------------
-- State Pattern: контекст источника транзакции
-- Отслеживаем какой UI открыт, чтобы определить откуда пришли деньги
-------------------------------------------------------------------------------
local currentSource = "unknown"

-- Таблица: WoW event → source key
local SOURCE_EVENTS = {
    -- Vendor
    MERCHANT_SHOW           = "vendor",
    MERCHANT_CLOSED         = "clear",

    -- Auction House
    AUCTION_HOUSE_SHOW      = "ah",
    AUCTION_HOUSE_CLOSED    = "clear",

    -- Mail
    MAIL_SHOW               = "mail",
    MAIL_CLOSED             = "clear",

    -- Trade
    TRADE_SHOW              = "trade",
    TRADE_CLOSED            = "clear",

    -- Quest
    QUEST_TURNED_IN         = "quest",

    -- Loot
    LOOT_OPENED             = "loot",
    LOOT_CLOSED             = "clear",

    -- Bank (bank tab purchases etc.; deposits/withdrawals are matched via hooks)
    BANKFRAME_OPENED        = "bank",
    BANKFRAME_CLOSED        = "clear",
    GUILDBANKFRAME_OPENED   = "guildbank",
    GUILDBANKFRAME_CLOSED   = "clear",
}

--- Возвращает текущий определённый источник
--- @return string source key
function Tracker:GetCurrentSource()
    return currentSource
end

--- Locale key для источника
--- @param source string
--- @return string
function Tracker:GetSourceLocaleKey(source)
    local map = {
        vendor  = "SRC_VENDOR",
        repair  = "SRC_REPAIR",
        ah      = "SRC_AH",
        mail    = "SRC_MAIL",
        quest   = "SRC_QUEST",
        loot    = "SRC_LOOT",
        trade   = "SRC_TRADE",
        bank    = "SRC_BANK",
        guildbank = "SRC_GUILDBANK",
        unknown = "SRC_UNKNOWN",
    }
    return map[source] or "SRC_UNKNOWN"
end

-------------------------------------------------------------------------------
-- Observer: callbacks при изменении голды
-------------------------------------------------------------------------------
local changeCallbacks = {}

--- Регистрирует callback на изменение голды
--- @param callback function(amount, entryType, newTotal, source)
function Tracker:OnGoldChanged(callback)
    table.insert(changeCallbacks, callback)
end

--- Уведомляет всех подписчиков об изменении
local function NotifyChange(amount, entryType, newTotal, source)
    for _, callback in ipairs(changeCallbacks) do
        callback(amount, entryType, newTotal, source)
    end
end

-------------------------------------------------------------------------------
-- Gold Detection
-------------------------------------------------------------------------------

function Tracker:GetCurrentGold()
    return GetMoney() or 0
end

function Tracker:GetLastGold()
    return lastGold
end

--- Статистика текущей сессии
--- @return table {income, expense, net}
function Tracker:GetSessionStats()
    return {
        income = sessionIncome,
        expense = sessionExpense,
        net = sessionIncome - sessionExpense,
    }
end

function Tracker:ResetSession()
    sessionIncome = 0
    sessionExpense = 0
end

--- Queues a bank money move captured by a hook
--- @param bank string "account"|"guild"
--- @param kind string "deposit"|"withdraw"
--- @param amount number copper
local function QueueBankOp(bank, kind, amount)
    if type(amount) ~= "number" or amount <= 0 then return end
    table.insert(pendingBankOps, { bank = bank, kind = kind, amount = amount, time = GetTime() })
    GoldLedger:Debug("Tracker", "Bank op captured:", bank, kind, amount)
end

--- Removes and returns the pending bank op matching this gold change, if any
--- @param absAmount number
--- @param entryType string "income"|"expense"
--- @return table|nil
local function TakeMatchingBankOp(absAmount, entryType)
    local now = GetTime()
    local wantKind = entryType == "expense" and "deposit" or "withdraw"
    for i = #pendingBankOps, 1, -1 do
        if now - pendingBankOps[i].time > BANK_OP_TIMEOUT then
            table.remove(pendingBankOps, i)
        end
    end
    for i, op in ipairs(pendingBankOps) do
        if op.kind == wantKind and op.amount == absAmount then
            return table.remove(pendingBankOps, i)
        end
    end
    return nil
end

--- Обрабатывает изменение голды
local function ProcessGoldChange()
    if not isReady then return end

    local currentGold = GetMoney()
    local delta = currentGold - lastGold

    if delta == 0 then
        lastGold = currentGold
        return
    end

    local absAmount = math.abs(delta)
    local entryType = delta > 0 and "income" or "expense"
    local source = currentSource

    -- Bank deposit/withdrawal. Warband bank gold is still the player's, so it's
    -- logged as a transfer (not income/expense). Guild bank gold isn't, so it
    -- stays income/expense but is labelled as guild bank.
    local bankOp = TakeMatchingBankOp(absAmount, entryType)
    if bankOp and bankOp.bank == "account" then
        GoldLedger:Debug("Tracker", "transfer | warband bank", bankOp.kind, "| delta:", delta)
        local Data = GoldLedger:GetModule("Data")
        if Data then
            Data:AddTransfer(delta, "bank")
        end
        lastGold = currentGold
        NotifyChange(absAmount, "transfer", currentGold, "bank")
        return
    elseif bankOp then
        source = "guildbank"
    end

    -- Детект ремонта: если у вендора, расход и был вызван RepairAllItems()
    if source == "vendor" and entryType == "expense" and repairPending then
        source = "repair"
        repairPending = false
    end

    -- Детект АХ-почты: смотрим ровно то письмо, по которому игрок только что
    -- кликнул "Получить деньги" (захвачено хуком на TakeInboxMoney). Если
    -- сумма мейла не совпадает с дельтой — это не наш мейл (третий аддон,
    -- multiple takes одновременно и т.п.), оставляем source="mail".
    if source == "mail" and entryType == "income" then
        local mail = table.remove(pendingMailQueue, 1)
        if mail and mail.money and mail.money == absAmount then
            -- Точное совпадение по сумме: это именно тот мейл.
            local senderEq = AUCTION_HOUSE_MAIL_SELLER and mail.sender == AUCTION_HOUSE_MAIL_SELLER
            if senderEq then
                source = "ah"
                GoldLedger:Debug("Tracker", "AH mail (exact sender):", mail.sender)
            end
        end
        -- Если очередь пуста (просроченный мейл вернул голд автоматически),
        -- или сумма не сошлась — остаёмся "mail". Это лучше чем ложно
        -- приписать доход к АХ.
    end

    -- Обновляем статистику сессии
    if entryType == "income" then
        sessionIncome = sessionIncome + absAmount
    else
        sessionExpense = sessionExpense + absAmount
    end

    -- Квест-контекст сбрасывается сразу после одной транзакции
    if currentSource == "quest" then
        currentSource = "unknown"
    end

    -- Debug
    GoldLedger:Debug("Tracker",
        entryType, "| source:", source,
        "| delta:", delta,
        "| before:", lastGold,
        "| after:", currentGold
    )

    -- Логируем через Data
    local Data = GoldLedger:GetModule("Data")
    if Data then
        Data:AddEntry(delta, source)
    end

    -- Уведомляем подписчиков
    NotifyChange(absAmount, entryType, currentGold, source)

    lastGold = currentGold
end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function Tracker:OnEnable()
    lastGold = GetMoney()
    isReady = true

    GoldLedger:Debug("Tracker", "Ready | starting gold:", lastGold)

    -- Хук на RepairAllItems() для отделения ремонта от покупок у вендора
    hooksecurefunc("RepairAllItems", function()
        repairPending = true
        GoldLedger:Debug("Tracker", "RepairAllItems() called — repair pending")
    end)

    -- Хук на TakeInboxMoney(index) — захватываем sender/subject/money мейла
    -- ДО того как он исчезнет из инбокса. Поддерживает Open All Mail (несколько
    -- последовательных вызовов) через FIFO-очередь.
    hooksecurefunc("TakeInboxMoney", function(index)
        local _, _, sender, subject, money = GetInboxHeaderInfo(index)
        if money and money > 0 then
            table.insert(pendingMailQueue, {
                sender  = sender,
                subject = subject,
                money   = money,
            })
            GoldLedger:Debug("Tracker", "TakeInboxMoney captured:", sender, "money:", money)
        end
    end)

    -- Warband bank money (C_Bank, Enum.BankType.Account)
    if C_Bank and Enum and Enum.BankType then
        hooksecurefunc(C_Bank, "DepositMoney", function(bankType, amount)
            if bankType == Enum.BankType.Account then QueueBankOp("account", "deposit", amount) end
        end)
        hooksecurefunc(C_Bank, "WithdrawMoney", function(bankType, amount)
            if bankType == Enum.BankType.Account then QueueBankOp("account", "withdraw", amount) end
        end)
    end

    -- Guild bank money
    if DepositGuildBankMoney then
        hooksecurefunc("DepositGuildBankMoney", function(amount) QueueBankOp("guild", "deposit", amount) end)
    end
    if WithdrawGuildBankMoney then
        hooksecurefunc("WithdrawGuildBankMoney", function(amount) QueueBankOp("guild", "withdraw", amount) end)
    end

    -- Warband bank balance: cache it and let the UI refresh
    local function RefreshWarbandBank()
        local Data = GoldLedger:GetModule("Data")
        if Data then
            Data:RefreshWarbandBankMoney()
        end
        GoldLedger.Events:Emit("WARBAND_BANK_UPDATED")
    end
    GoldLedger:RegisterEvent("ACCOUNT_MONEY", RefreshWarbandBank)
    GoldLedger:RegisterEvent("BANKFRAME_OPENED", RefreshWarbandBank)

    -- Подписка на изменение голды
    GoldLedger:RegisterEvent("PLAYER_MONEY", function()
        ProcessGoldChange()
    end)

    -- Подписка на контекстные ивенты для определения источника
    for event, sourceKey in pairs(SOURCE_EVENTS) do
        GoldLedger:RegisterEvent(event, function()
            if sourceKey == "clear" then
                currentSource = "unknown"
            else
                currentSource = sourceKey
            end
            GoldLedger:Debug("Tracker", "Context →", currentSource, "(from " .. event .. ")")
        end)
    end
end
