--[[
    Copperwise: Data.lua
    Pattern: Facade

    Единый интерфейс для работы с данными:
    - Инициализация SavedVariables с defaults
    - CRUD для записей транзакций
    - Агрегация: дневные и месячные итоги
    - Авто-очистка старых записей (>90 дней)
]]

local ADDON_NAME, ns = ...
local Copperwise = ns.Copperwise
local L = ns.L

local Data = {}
Copperwise:RegisterModule("Data", Data)

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local MAX_ENTRIES = 5000            -- Макс. записей на персонажа
local CLEANUP_AGE_DAYS = 365       -- Удалять записи старше N дней
local SECONDS_PER_DAY = 86400

-------------------------------------------------------------------------------
-- SavedVariables defaults
-------------------------------------------------------------------------------
local DB_DEFAULTS = {
    characters = {},
    settings = {
        showMinimap = true,  -- button position/visibility: settings.minimap (LibDBIcon)
        theme = "dashboard_cards",
        language = nil,  -- nil = auto (game locale)
    },
    modules = {},  -- per-feature namespaced data
}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

--- Возвращает ключ текущего персонажа: "Name-Realm"
--- @return string
function Data:GetCharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

--- Текущая дата в формате "YYYY-MM-DD"
--- @return string
function Data:GetDateKey()
    return date("%Y-%m-%d")
end

--- Дата вчерашнего дня в формате "YYYY-MM-DD"
--- (корректно перепрыгивает границы месяца/года, потому что time()-86400
--- падает в предыдущие сутки в любой временной зоне)
--- @return string
function Data:GetYesterdayDateKey()
    return date("%Y-%m-%d", time() - SECONDS_PER_DAY)
end

--- Текущий месяц в формате "YYYY-MM"
--- @return string
function Data:GetMonthKey()
    return date("%Y-%m")
end

--- Deep copy defaults в target (не перезаписывает существующие)
--- @param target table
--- @param defaults table
local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            ApplyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

-------------------------------------------------------------------------------
-- Lifecycle (вызывается из Core)
-------------------------------------------------------------------------------

--- Инициализация SavedVariables
function Data:OnInitialize()
    -- Создаём или мёржим с defaults
    if not CopperwiseDB then
        CopperwiseDB = {}
    end
    ApplyDefaults(CopperwiseDB, DB_DEFAULTS)
    self:ImportFromGoldLedger()

    -- Восстановить сохранённый язык
    local savedLang = CopperwiseDB.settings.language
    if savedLang and savedLang ~= "auto" then
        L:SetLocale(savedLang)
    end

    -- Гарантируем структуру для текущего персонажа
    self:EnsureCharacterData()

    -- Очистка старых записей
    self:CleanupOldEntries()
end

local function DeepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = DeepCopy(v) end
    return copy
end

--- One-time import for players switching from GoldLedger, which Copperwise is
--- based on. A SavedVariables table is only loaded with the addon that owns it,
--- so this works when GoldLedger is still enabled on the first Copperwise login;
--- after that GoldLedger can be disabled. Only runs while Copperwise has no data.
function Data:ImportFromGoldLedger()
    local old = _G.GoldLedgerDB
    if type(old) ~= "table" or type(old.characters) ~= "table" then return end
    if next(CopperwiseDB.characters) ~= nil or CopperwiseDB.importedFromGoldLedger then return end

    local characters, entries = 0, 0
    for key, charData in pairs(old.characters) do
        CopperwiseDB.characters[key] = DeepCopy(charData)
        characters = characters + 1
        entries = entries + (type(charData.entries) == "table" and #charData.entries or 0)
    end
    if type(old.warbandBank) == "table" then
        CopperwiseDB.warbandBank = DeepCopy(old.warbandBank)
    end
    if type(old.settings) == "table" and old.settings.goalAmount then
        CopperwiseDB.settings.goalAmount = old.settings.goalAmount
    end
    CopperwiseDB.importedFromGoldLedger = time()

    C_Timer.After(2, function()
        print("|cffb87333Copperwise|r " .. L["IMPORTED_GOLDLEDGER"]:format(entries, characters))
    end)
end

--- Гарантирует наличие данных текущего персонажа
function Data:EnsureCharacterData()
    local key = self:GetCharKey()
    if not CopperwiseDB.characters[key] then
        CopperwiseDB.characters[key] = {
            entries = {},
            daily = {},
            monthly = {},
        }
    end
    return CopperwiseDB.characters[key]
end

-------------------------------------------------------------------------------
-- Module Namespace API (Ace3-inspired)
-- Feature modules get their own section in CopperwiseDB.modules[name]
-------------------------------------------------------------------------------

--- Регистрирует namespace для feature-модуля с defaults
--- @param name string Имя namespace (e.g. "auction")
--- @param defaults table Структура по умолчанию
--- @return table Ссылка на namespace data в CopperwiseDB.modules[name]
function Data:RegisterNamespace(name, defaults)
    if not CopperwiseDB.modules then
        CopperwiseDB.modules = {}
    end
    if not CopperwiseDB.modules[name] then
        CopperwiseDB.modules[name] = {}
    end
    -- Merge defaults (не перезаписывает существующие)
    if defaults then
        local function applyDefaults(target, defs)
            for k, v in pairs(defs) do
                if type(v) == "table" then
                    if type(target[k]) ~= "table" then target[k] = {} end
                    applyDefaults(target[k], v)
                elseif target[k] == nil then
                    target[k] = v
                end
            end
        end
        applyDefaults(CopperwiseDB.modules[name], defaults)
    end
    return CopperwiseDB.modules[name]
end

--- Возвращает namespace data для feature-модуля
--- @param name string Имя namespace
--- @return table|nil
function Data:GetNamespace(name)
    return CopperwiseDB and CopperwiseDB.modules and CopperwiseDB.modules[name]
end

-------------------------------------------------------------------------------
-- Facade API: CRUD
-------------------------------------------------------------------------------

--- Добавляет запись о транзакции
--- @param amount number Сумма в copper (положительная = доход, отрицательная = расход)
--- @param source string|nil Источник: "vendor", "ah", "mail", "quest", "loot", "trade", "unknown"
--- @param meta table|nil Опциональные метаданные { itemName, ahType, quantity, unitPrice, grossAmount, cutAmount }
---                       Ядро хранит их прозрачно, не интерпретирует. Используется модулями (AuctionTracker).
--- @return table|nil The stored entry (callers may annotate it, e.g. vendor sale item names)
function Data:AddEntry(amount, source, meta)
    if amount == 0 then return end

    local charData = self:EnsureCharacterData()
    local now = time()
    local dateKey = self:GetDateKey()
    local monthKey = self:GetMonthKey()
    local entryType = amount > 0 and "income" or "expense"
    local absAmount = math.abs(amount)

    -- 1. Добавить запись в лог
    local entry = {
        timestamp = now,
        amount = absAmount,
        type = entryType,
        source = source or "unknown",
    }
    if type(meta) == "table" then
        entry.itemName    = meta.itemName
        entry.ahType      = meta.ahType
        entry.quantity    = meta.quantity
        entry.unitPrice   = meta.unitPrice
        entry.grossAmount = meta.grossAmount
        entry.cutAmount   = meta.cutAmount
    end
    table.insert(charData.entries, entry)
    self:TrimEntries(charData)

    -- 2. Обновить дневной итог
    if not charData.daily[dateKey] then
        charData.daily[dateKey] = { income = 0, expense = 0 }
    end
    charData.daily[dateKey][entryType] = charData.daily[dateKey][entryType] + absAmount

    -- 3. Обновить месячный итог
    if not charData.monthly[monthKey] then
        charData.monthly[monthKey] = { income = 0, expense = 0 }
    end
    charData.monthly[monthKey][entryType] = charData.monthly[monthKey][entryType] + absAmount

    return entry
end

--- Ограничение размера: удаляем самые старые
function Data:TrimEntries(charData)
    while #charData.entries > MAX_ENTRIES do
        table.remove(charData.entries, 1)
    end
end

--- Records a move of gold between the character and a bank it still owns
--- (warband bank). Logged with type "transfer" so it shows in the transaction
--- list but is excluded from income/expense totals, charts and session stats.
--- @param amount number Copper delta on the character (negative = deposit, positive = withdrawal)
--- @param source string|nil Source key, default "bank"
function Data:AddTransfer(amount, source)
    if amount == 0 then return end

    local charData = self:EnsureCharacterData()
    table.insert(charData.entries, {
        timestamp = time(),
        amount    = math.abs(amount),
        type      = "transfer",
        direction = amount < 0 and "deposit" or "withdraw",
        source    = source or "bank",
    })
    self:TrimEntries(charData)
end

-------------------------------------------------------------------------------
-- Warband bank balance (account-wide, so stored outside per-character data)
-------------------------------------------------------------------------------

--- Caches the warband bank balance from the server
function Data:RefreshWarbandBankMoney()
    if not (C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType) then return end
    local amount = C_Bank.FetchDepositedMoney(Enum.BankType.Account)
    if type(amount) ~= "number" then return end
    CopperwiseDB.warbandBank = { amount = amount, updated = time() }
end

--- Last known warband bank balance in copper (0 if never seen)
--- @return number
function Data:GetWarbandBankMoney()
    local wb = CopperwiseDB and CopperwiseDB.warbandBank
    return wb and wb.amount or 0
end

--- Возвращает итоги за день
--- @param dateKey string|nil Дата "YYYY-MM-DD", nil = сегодня
--- @return table {income=number, expense=number}
function Data:GetDailySummary(dateKey)
    dateKey = dateKey or self:GetDateKey()
    local charData = self:EnsureCharacterData()
    return charData.daily[dateKey] or { income = 0, expense = 0 }
end

--- Возвращает итоги за месяц
--- @param monthKey string|nil Месяц "YYYY-MM", nil = текущий
--- @return table {income=number, expense=number}
function Data:GetMonthlySummary(monthKey)
    monthKey = monthKey or self:GetMonthKey()
    local charData = self:EnsureCharacterData()
    return charData.monthly[monthKey] or { income = 0, expense = 0 }
end

--- Возвращает данные по дням текущего месяца для графика (legacy)
--- @return table[] { {day=1, income=N, expense=N}, ... }, number maxValue
function Data:GetMonthlyChartData()
    return self:GetChartData("30d")
end

--- Возвращает данные для графика за указанный период
--- @param period string "7d"|"30d"|"all"
--- @return table[] { {label=string, dateKey=string, income=N, expense=N}, ... }, number maxValue, number count
function Data:GetChartData(period)
    local charData = self:EnsureCharacterData()
    local result = {}
    local maxVal = 1

    if period == "7d" then
        -- Последние 7 дней
        local now = time()
        for i = 6, 0, -1 do
            local t = now - i * SECONDS_PER_DAY
            local dateKey = date("%Y-%m-%d", t)
            local dayNum = tonumber(date("%d", t))
            local summary = charData.daily[dateKey] or { income = 0, expense = 0 }
            table.insert(result, {
                label = tostring(dayNum),
                dateKey = dateKey,
                income = summary.income,
                expense = summary.expense,
            })
            maxVal = math.max(maxVal, summary.income, summary.expense)
        end
        return result, maxVal, 7

    elseif period == "all" then
        -- Все дни с данными, сортированные по дате
        local dateKeys = {}
        for dateKey in pairs(charData.daily) do
            table.insert(dateKeys, dateKey)
        end
        table.sort(dateKeys)

        for _, dateKey in ipairs(dateKeys) do
            local summary = charData.daily[dateKey]
            local dayNum = dateKey:match("%d+-%d+-(%d+)")
            table.insert(result, {
                label = dayNum,
                dateKey = dateKey,
                income = summary.income,
                expense = summary.expense,
            })
            maxVal = math.max(maxVal, summary.income, summary.expense)
        end
        local count = #result
        if count == 0 then count = 1 end
        return result, maxVal, count

    else -- "30d" default: последние 30 дней
        local now = time()
        for i = 29, 0, -1 do
            local t = now - i * SECONDS_PER_DAY
            local dateKey = date("%Y-%m-%d", t)
            local dayNum = tonumber(date("%d", t))
            local summary = charData.daily[dateKey] or { income = 0, expense = 0 }
            table.insert(result, {
                label = tostring(dayNum),
                dateKey = dateKey,
                income = summary.income,
                expense = summary.expense,
            })
            maxVal = math.max(maxVal, summary.income, summary.expense)
        end
        return result, maxVal, 30
    end
end

--- Возвращает последние N записей (новые первыми)
--- @param count number Количество записей
--- @return table[] Массив записей
function Data:GetRecentEntries(count)
    count = count or 50
    local charData = self:EnsureCharacterData()
    local entries = charData.entries
    local result = {}
    local start = math.max(1, #entries - count + 1)

    for i = #entries, start, -1 do
        table.insert(result, entries[i])
    end

    return result
end

--- Возвращает настройки аддона
--- @return table
function Data:GetSettings()
    return CopperwiseDB.settings
end

-------------------------------------------------------------------------------
-- Reset & Cleanup
-------------------------------------------------------------------------------

--- Сбрасывает данные текущего персонажа
function Data:ResetCharacterData()
    local key = self:GetCharKey()
    CopperwiseDB.characters[key] = nil
    self:EnsureCharacterData()
end

-------------------------------------------------------------------------------
-- Goal API
-------------------------------------------------------------------------------

--- Устанавливает цель накопления (в copper)
--- @param amount number Сумма в copper
function Data:SetGoal(amount)
    CopperwiseDB.settings.goalAmount = amount
end

--- Возвращает текущую цель (в copper), 0 если нет
--- @return number
function Data:GetGoal()
    return CopperwiseDB.settings.goalAmount or 0
end

--- Сбрасывает цель
function Data:ClearGoal()
    CopperwiseDB.settings.goalAmount = nil
end

--- Возвращает прогресс к цели
--- @return table|nil {goal, current, progress(0-1), remaining, estDays}
function Data:GetGoalProgress()
    local goal = self:GetGoal()
    if goal <= 0 then return nil end

    -- Gold moved into the warband bank still counts towards the goal
    local currentGold = (GetMoney() or 0) + self:GetWarbandBankMoney()
    local progress = currentGold / goal
    local remaining = goal - currentGold

    -- Оценка дней: средний ежедневный чистый доход
    local charData = self:EnsureCharacterData()
    local totalNet = 0
    local days = 0
    for _, summary in pairs(charData.daily) do
        totalNet = totalNet + (summary.income - summary.expense)
        days = days + 1
    end

    local avgDaily = days > 0 and (totalNet / days) or 0
    local estDays = (avgDaily > 0 and remaining > 0) and math.ceil(remaining / avgDaily) or nil

    return {
        goal = goal,
        current = currentGold,
        progress = math.min(1, progress),
        remaining = remaining,
        estDays = estDays,
    }
end

-------------------------------------------------------------------------------
-- Multi-character API
-------------------------------------------------------------------------------

--- Возвращает сводку по всем персонажам за указанный период
--- @param period string|nil "day"|"week"|"month" (default: "month")
--- @return table[] { {name, income, expense, net}, ... }
function Data:GetAllCharactersSummary(period)
    period = period or "month"
    local result = {}
    if not CopperwiseDB or not CopperwiseDB.characters then return result end

    local dateKey = self:GetDateKey()
    local monthKey = self:GetMonthKey()

    for charKey, charData in pairs(CopperwiseDB.characters) do
        local income, expense = 0, 0

        if period == "day" then
            local daily = charData.daily and charData.daily[dateKey]
            if daily then
                income, expense = daily.income, daily.expense
            end
        elseif period == "week" then
            local now = time()
            local cutoff = now - 7 * SECONDS_PER_DAY
            if charData.daily then
                for dk, daily in pairs(charData.daily) do
                    local y, m, d = dk:match("^(%d+)-(%d+)-(%d+)$")
                    if y then
                        local t = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0 })
                        if t >= cutoff then
                            income = income + (daily.income or 0)
                            expense = expense + (daily.expense or 0)
                        end
                    end
                end
            end
        else -- "month"
            local monthly = charData.monthly and charData.monthly[monthKey]
            if monthly then
                income, expense = monthly.income, monthly.expense
            end
        end

        table.insert(result, {
            name = charKey,
            income = income,
            expense = expense,
            net = income - expense,
        })
    end

    table.sort(result, function(a, b) return a.net > b.net end)
    return result
end

-------------------------------------------------------------------------------
-- Source Breakdown API
-------------------------------------------------------------------------------

--- Все источники в порядке отображения
Data.ALL_SOURCES = {"vendor", "repair", "ah", "mail", "quest", "loot", "trade", "bank", "guildbank", "unknown"}

--- Возвращает разбивку по источникам за период
--- @param period string "today"|"week"|"month"|"all"
--- @return table sourceTotals { [source] = {income=N, expense=N} }
--- @return table grandTotals {income=N, expense=N}
function Data:GetSourceBreakdown(period)
    local charData = self:EnsureCharacterData()

    -- Вычисляем cutoff
    local cutoff = 0
    if period == "today" then
        local d = date("*t")
        d.hour, d.min, d.sec = 0, 0, 0
        cutoff = time(d)
    elseif period == "week" then
        cutoff = time() - 7 * SECONDS_PER_DAY
    elseif period == "month" then
        cutoff = time() - 30 * SECONDS_PER_DAY
    end
    -- "all" → cutoff = 0, все записи

    local sourceTotals = {}
    for _, src in ipairs(self.ALL_SOURCES) do
        sourceTotals[src] = { income = 0, expense = 0 }
    end

    local grandTotals = { income = 0, expense = 0 }

    for _, entry in ipairs(charData.entries) do
        -- Bank transfers are neither income nor expense
        if entry.timestamp >= cutoff and entry.type ~= "transfer" then
            local src = entry.source or "unknown"
            if not sourceTotals[src] then
                sourceTotals[src] = { income = 0, expense = 0 }
            end
            sourceTotals[src][entry.type] = sourceTotals[src][entry.type] + entry.amount
            grandTotals[entry.type] = grandTotals[entry.type] + entry.amount
        end
    end

    return sourceTotals, grandTotals
end

-------------------------------------------------------------------------------
-- Filtered Entries API (pagination + search)
-------------------------------------------------------------------------------

--- Возвращает отфильтрованные записи с пагинацией
--- @param options table { page=1, perPage=50, source="all", entryType="all", minAmount=0 }
--- @return table { entries={...}, total=N, page=N, totalPages=N }
function Data:GetFilteredEntries(options)
    options = options or {}
    local page = options.page or 1
    local perPage = options.perPage or 50
    local sourceFilter = options.source or "all"
    local typeFilter = options.entryType or "all"
    local minAmount = options.minAmount or 0

    local charData = self:EnsureCharacterData()

    -- Фильтруем все записи (reverse order — newest first)
    local filtered = {}
    for i = #charData.entries, 1, -1 do
        local entry = charData.entries[i]
        local match = true

        if sourceFilter ~= "all" and (entry.source or "unknown") ~= sourceFilter then
            match = false
        end
        if typeFilter ~= "all" and entry.type ~= typeFilter then
            match = false
        end
        if minAmount > 0 and entry.amount < minAmount then
            match = false
        end

        if match then
            filtered[#filtered + 1] = entry
        end
    end

    local total = #filtered
    local totalPages = perPage > 0 and math.ceil(total / perPage) or 0

    -- Извлекаем нужную страницу
    local startIdx = (page - 1) * perPage + 1
    local endIdx = math.min(page * perPage, total)
    local entries = {}

    if startIdx <= total then
        for i = startIdx, endIdx do
            entries[#entries + 1] = filtered[i]
        end
    end

    return {
        entries = entries,
        total = total,
        page = page,
        totalPages = totalPages,
    }
end

-------------------------------------------------------------------------------
-- Export API
-------------------------------------------------------------------------------

--- Возвращает CSV-строку всех записей текущего персонажа
--- @return string CSV data
function Data:GetExportCSV()
    local charData = self:EnsureCharacterData()
    local lines = { "timestamp,date,time,type,amount_copper,amount_gold,source" }

    for _, entry in ipairs(charData.entries) do
        local dateStr = date("%Y-%m-%d", entry.timestamp)
        local timeStr = date("%H:%M:%S", entry.timestamp)
        local goldAmount = entry.amount / 10000
        -- Transfers export as "bank_deposit" / "bank_withdraw"
        local typeStr = entry.type == "transfer" and ("bank_" .. (entry.direction or "deposit")) or entry.type
        table.insert(lines, ("%d,%s,%s,%s,%d,%.2f,%s"):format(
            entry.timestamp, dateStr, timeStr,
            typeStr, entry.amount, goldAmount,
            entry.source or "unknown"
        ))
    end

    return table.concat(lines, "\n")
end

--- Удаляет записи старше CLEANUP_AGE_DAYS
function Data:CleanupOldEntries()
    local charData = self:EnsureCharacterData()
    local cutoff = time() - (CLEANUP_AGE_DAYS * SECONDS_PER_DAY)
    local entries = charData.entries
    local cleaned = {}

    for _, entry in ipairs(entries) do
        if entry.timestamp >= cutoff then
            table.insert(cleaned, entry)
        end
    end

    charData.entries = cleaned

    -- Очистка старых дневных итогов
    local dateCutoff = date("%Y-%m-%d", cutoff)
    for dateKey in pairs(charData.daily) do
        if dateKey < dateCutoff then
            charData.daily[dateKey] = nil
        end
    end

    -- Очистка старых месячных итогов (>6 месяцев)
    local monthCutoff = date("%Y-%m", cutoff)
    for monthKey in pairs(charData.monthly) do
        if monthKey < monthCutoff then
            charData.monthly[monthKey] = nil
        end
    end
end
