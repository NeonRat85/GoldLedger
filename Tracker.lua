--[[
    Copperwise: Tracker.lua
    Patterns: Observer, State

    Tracks gold changes through WoW events:
    - PLAYER_LOGIN → remembers the starting balance
    - PLAYER_MONEY → works out the change and logs it through Data
    - Context events → work out the source (vendor, AH, mail, etc.)
    - Callbacks that notify the UI of changes
]]

local ADDON_NAME, ns = ...
local Copperwise = ns.Copperwise
local L = ns.L

local Tracker = {}
Copperwise:RegisterModule("Tracker", Tracker)

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local lastGold = 0          -- Last known gold amount (copper)
local isReady = false       -- Tracker ready (after PLAYER_LOGIN)
local sessionIncome = 0     -- Income this session (copper)
local sessionExpense = 0    -- Expense this session (copper)
local repairPending = false -- Set when RepairAllItems() was called

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
-- State Pattern: transaction source context
-- Tracks which UI is open, to tell where money came from
-------------------------------------------------------------------------------
local currentSource = "unknown"

-- Map: WoW event → source key
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

--- Returns the current source
--- @return string source key
function Tracker:GetCurrentSource()
    return currentSource
end

--- Locale key for a source
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
-- Observer: gold change callbacks
-------------------------------------------------------------------------------
local changeCallbacks = {}

--- Registers a gold change callback
--- @param callback function(amount, entryType, newTotal, source)
function Tracker:OnGoldChanged(callback)
    table.insert(changeCallbacks, callback)
end

--- Notifies every subscriber of a change
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

--- Current session stats
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
    Copperwise:Debug("Tracker", "Bank op captured:", bank, kind, amount)
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

-------------------------------------------------------------------------------
-- Vendor sales: item names from the merchant buyback list
-------------------------------------------------------------------------------
-- Every item sold to a vendor lands in the buyback list (newest last) with its
-- name, quantity and total sale price, whatever the sell method: right-click,
-- drag, Sell Junk or a vendoring addon. PLAYER_MONEY and the list update can
-- arrive in either order, so vendor income entries wait in pendingVendorSales
-- until a matching new buyback item appears, or expire.
local VENDOR_MATCH_TIMEOUT = 5
local buybackBaseline = {}      -- [signature] = copies already in the list or claimed
local pendingVendorSales = {}   -- { entry = <Data entry>, amount = copper, time = GetTime() }

local function BuybackSignature(name, price, quantity)
    return name .. "\031" .. price .. "\031" .. quantity
end

--- Current buyback list, newest first
local function ReadBuyback()
    local items, counts = {}, {}
    local num = GetNumBuybackItems and GetNumBuybackItems() or 0
    for i = num, 1, -1 do
        local name, _, price, quantity = GetBuybackItemInfo(i)
        if name and price and price > 0 then
            quantity = quantity or 1
            local sig = BuybackSignature(name, price, quantity)
            counts[sig] = (counts[sig] or 0) + 1
            items[#items + 1] = { sig = sig, name = name, price = price, quantity = quantity }
        end
    end
    return items, counts
end

--- Everything already in the buyback list when the merchant opens was sold earlier
local function ResetBuybackBaseline()
    local _, counts = ReadBuyback()
    buybackBaseline = counts
    wipe(pendingVendorSales)
end

--- Buyback items not yet matched to a sale, newest first. For each signature the
--- newest (count - baseline) copies are new.
local function GetUnclaimedBuyback()
    local items, counts = ReadBuyback()
    local seen, unclaimed = {}, {}
    for _, item in ipairs(items) do
        -- The list holds 12 items; older copies drop off the end as new ones arrive
        if (buybackBaseline[item.sig] or 0) > counts[item.sig] then
            buybackBaseline[item.sig] = counts[item.sig]
        end
        seen[item.sig] = (seen[item.sig] or 0) + 1
        if seen[item.sig] <= counts[item.sig] - (buybackBaseline[item.sig] or 0) then
            unclaimed[#unclaimed + 1] = item
        end
    end
    return unclaimed
end

local function ItemLabel(item)
    return item.quantity > 1 and ("%s (%d)"):format(item.name, item.quantity) or item.name
end

--- Matches pending vendor income to new buyback items and names the entries
local function ResolveVendorSales()
    if #pendingVendorSales == 0 then return end
    local unclaimed = GetUnclaimedBuyback()
    local now = GetTime()
    local updated = false

    local i = 1
    while i <= #pendingVendorSales do
        local sale = pendingVendorSales[i]
        local matched

        for _, item in ipairs(unclaimed) do
            if not item.claimed and item.price == sale.amount then
                matched = { item }
                break
            end
        end

        -- One money change for several items at once (e.g. Sell Junk)
        if not matched then
            local total, group = 0, {}
            for _, item in ipairs(unclaimed) do
                if not item.claimed then
                    total = total + item.price
                    group[#group + 1] = item
                end
            end
            if #group > 1 and total == sale.amount then matched = group end
        end

        if matched then
            local entry = sale.entry
            entry.vendorType = "sale"
            for _, item in ipairs(matched) do
                item.claimed = true
                buybackBaseline[item.sig] = (buybackBaseline[item.sig] or 0) + 1
            end
            if #matched == 1 then
                entry.itemName = ItemLabel(matched[1])
                entry.quantity = matched[1].quantity
            else
                local names = {}
                entry.items = {}
                for n, item in ipairs(matched) do
                    if n <= 3 then names[#names + 1] = ItemLabel(item) end
                    entry.items[n] = { name = item.name, quantity = item.quantity, price = item.price }
                end
                local more = #matched - 3
                entry.itemName = table.concat(names, ", ") .. (more > 0 and (" +%d more"):format(more) or "")
            end
            Copperwise:Debug("Tracker", "Vendor sale matched:", entry.itemName, "| amount:", sale.amount)
            table.remove(pendingVendorSales, i)
            updated = true
        elseif now - sale.time > VENDOR_MATCH_TIMEOUT then
            Copperwise:Debug("Tracker", "Vendor sale unmatched, giving up | amount:", sale.amount)
            table.remove(pendingVendorSales, i)
        else
            i = i + 1
        end
    end

    if updated then
        Copperwise.Events:Emit("ENTRIES_UPDATED")
    end
end

--- Handles a gold change
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
        Copperwise:Debug("Tracker", "transfer | warband bank", bankOp.kind, "| delta:", delta)
        local Data = Copperwise:GetModule("Data")
        if Data then
            Data:AddTransfer(delta, "bank")
        end
        lastGold = currentGold
        NotifyChange(absAmount, "transfer", currentGold, "bank")
        return
    elseif bankOp then
        source = "guildbank"
    end

    -- Repair detection: at a vendor, spending, and RepairAllItems() was called
    if source == "vendor" and entryType == "expense" and repairPending then
        source = "repair"
        repairPending = false
    end

    -- AH mail detection: look at exactly the mail the player just
    -- took money from (captured by the TakeInboxMoney hook). If
    -- the mail amount doesn't match the change, it isn't this mail (another addon,
    -- several takes at once, etc.), so keep source="mail".
    if source == "mail" and entryType == "income" then
        local mail = table.remove(pendingMailQueue, 1)
        if mail and mail.money and mail.money == absAmount then
            -- Exact amount match: this is the mail.
            local senderEq = AUCTION_HOUSE_MAIL_SELLER and mail.sender == AUCTION_HOUSE_MAIL_SELLER
            if senderEq then
                source = "ah"
                Copperwise:Debug("Tracker", "AH mail (exact sender):", mail.sender)
            end
        end
        -- If the queue is empty (an expired mail returned gold automatically)
        -- or the amount didn't match, stay "mail". Better than wrongly
        -- crediting the income to the AH.
    end

    -- Update session stats
    if entryType == "income" then
        sessionIncome = sessionIncome + absAmount
    else
        sessionExpense = sessionExpense + absAmount
    end

    -- Quest context resets after a single transaction
    if currentSource == "quest" then
        currentSource = "unknown"
    end

    -- Debug
    Copperwise:Debug("Tracker",
        entryType, "| source:", source,
        "| delta:", delta,
        "| before:", lastGold,
        "| after:", currentGold
    )

    -- Log through Data
    local Data = Copperwise:GetModule("Data")
    local entry = Data and Data:AddEntry(delta, source)

    -- Notify subscribers
    NotifyChange(absAmount, entryType, currentGold, source)

    lastGold = currentGold

    -- Name the item(s) sold, now or when the buyback list catches up
    if entry and source == "vendor" and entryType == "income" then
        table.insert(pendingVendorSales, { entry = entry, amount = absAmount, time = GetTime() })
        ResolveVendorSales()
    end
end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

function Tracker:OnEnable()
    lastGold = GetMoney()
    isReady = true

    Copperwise:Debug("Tracker", "Ready | starting gold:", lastGold)

    -- Hook RepairAllItems() to tell repairs apart from vendor purchases
    hooksecurefunc("RepairAllItems", function()
        repairPending = true
        Copperwise:Debug("Tracker", "RepairAllItems() called — repair pending")
    end)

    -- Hook TakeInboxMoney(index): capture the mail's sender/subject/money
    -- BEFORE it leaves the inbox. Supports Open All Mail (several
    -- calls in a row) through a FIFO queue.
    hooksecurefunc("TakeInboxMoney", function(index)
        local _, _, sender, subject, money = GetInboxHeaderInfo(index)
        if money and money > 0 then
            table.insert(pendingMailQueue, {
                sender  = sender,
                subject = subject,
                money   = money,
            })
            Copperwise:Debug("Tracker", "TakeInboxMoney captured:", sender, "money:", money)
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
        local Data = Copperwise:GetModule("Data")
        if Data then
            Data:RefreshWarbandBankMoney()
        end
        Copperwise.Events:Emit("WARBAND_BANK_UPDATED")
    end
    Copperwise:RegisterEvent("ACCOUNT_MONEY", RefreshWarbandBank)
    Copperwise:RegisterEvent("BANKFRAME_OPENED", RefreshWarbandBank)

    -- Vendor sale item names (buyback list)
    Copperwise:RegisterEvent("MERCHANT_SHOW", ResetBuybackBaseline)
    Copperwise:RegisterEvent("MERCHANT_UPDATE", ResolveVendorSales)
    Copperwise:RegisterEvent("MERCHANT_CLOSED", function() wipe(pendingVendorSales) end)

    -- Subscribe to gold changes
    Copperwise:RegisterEvent("PLAYER_MONEY", function()
        ProcessGoldChange()
    end)

    -- Subscribe to context events to work out the source
    for event, sourceKey in pairs(SOURCE_EVENTS) do
        Copperwise:RegisterEvent(event, function()
            if sourceKey == "clear" then
                currentSource = "unknown"
            else
                currentSource = sourceKey
            end
            Copperwise:Debug("Tracker", "Context →", currentSource, "(from " .. event .. ")")
        end)
    end
end
