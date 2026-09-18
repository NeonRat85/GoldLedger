-- Minimal WoW API stub that loads Copperwise's real Locale/Core/Data/Tracker and
-- drives bank deposits, withdrawals and other gold changes through PLAYER_MONEY.
-- Usage: luajit tests/harness.lua [addon directory]

local dir = ... or "."
-- ---- WoW mocks -------------------------------------------------------------
local money, now, accountMoney = 1000000, 100, 500000
local eventFrames = {}
function CreateFrame()
  local f = { events = {} }
  function f:RegisterEvent(e) self.events[e] = true end
  function f:UnregisterEvent(e) self.events[e] = nil end
  function f:SetScript(k, fn) self[k] = fn end
  eventFrames[#eventFrames + 1] = f
  return f
end
local function fire(event, ...)
  for _, f in ipairs(eventFrames) do
    if f.events[event] and f.OnEvent then f.OnEvent(f, event, ...) end
  end
end
function GetLocale() return "enUS" end
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
function GetMoney() return money end
function GetTime() return now end
SlashCmdList = {}
time, date = os.time, os.date
C_AddOns = { GetAddOnMetadata = function() return "2.4.4" end }
C_Timer = { After = function(_, fn) end }
function hooksecurefunc(a, b, c)
  local t, name, hook = _G, a, b
  if type(a) == "table" then t, name, hook = a, b, c end
  local orig = t[name]
  t[name] = function(...) local r = { orig(...) }; hook(...); return unpack(r) end
end
Enum = { BankType = { Character = 0, Guild = 1, Account = 2 } }
C_Bank = {
  DepositMoney  = function(bt, amt) money = money - amt; accountMoney = accountMoney + amt end,
  WithdrawMoney = function(bt, amt) money = money + amt; accountMoney = accountMoney - amt end,
  FetchDepositedMoney = function(bt) return accountMoney end,
}
function DepositGuildBankMoney(amt) money = money - amt end
function WithdrawGuildBankMoney(amt) money = money + amt end
function RepairAllItems() end
function TakeInboxMoney() end
function GetInboxHeaderInfo() end
-- Merchant buyback list, newest last: { name, price, quantity }
local buyback = {}
function GetNumBuybackItems() return #buyback end
function GetBuybackItemInfo(i) local b = buyback[i]; if b then return b[1], 0, b[2], b[3] end end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
print = print

-- ---- Load the addon's real core files ----------------------------------------
local ns = {}
for _, f in ipairs({ "Locale.lua", "Core.lua", "Data.lua", "Tracker.lua" }) do
  local chunk = assert(loadfile(dir .. "/" .. f))
  chunk("Copperwise", ns)
end
-- Data left by GoldLedger (still enabled on the first Copperwise login)
GoldLedgerDB = {
  characters = { ["Oldchar-Realm"] = { entries = {
    { timestamp = 1, type = "income", source = "loot", amount = 500 },
    { timestamp = 2, type = "expense", source = "repair", amount = 200 },
  }, daily = {}, monthly = {} } },
  warbandBank = { amount = 123, updated = 1 },
  settings = { goalAmount = 999 },
}
fire("ADDON_LOADED", "Copperwise")
fire("PLAYER_LOGIN")

local GL = ns.Copperwise
local Data, Tracker = GL:GetModule("Data"), GL:GetModule("Tracker")
assert(Data and Tracker, "modules not registered")

local notified = {}
Tracker:OnGoldChanged(function(amount, entryType, total, source)
  notified[#notified + 1] = entryType .. ":" .. source
end)
local uiRefreshes = 0
GL.Events:On("WARBAND_BANK_UPDATED", function() uiRefreshes = uiRefreshes + 1 end)

local fails = 0
local function check(label, cond)
  print((cond and "PASS " or "FAIL ") .. label)
  if not cond then fails = fails + 1 end
end
local function last() return Data:GetRecentEntries(1)[1] end

-- 0. One-time import from GoldLedger
local imported = CopperwiseDB.characters["Oldchar-Realm"]
check("GoldLedger data imported", imported and #imported.entries == 2 and CopperwiseDB.importedFromGoldLedger ~= nil)
check("import is a copy, not shared", imported ~= GoldLedgerDB.characters["Oldchar-Realm"])
check("goal and warband bank imported", CopperwiseDB.settings.goalAmount == 999 and CopperwiseDB.warbandBank.amount == 123)
GoldLedgerDB.characters["Another-Realm"] = { entries = {} }
Data:ImportFromGoldLedger()
check("import only happens once", CopperwiseDB.characters["Another-Realm"] == nil)

-- 1. Warband bank deposit is a transfer, not an expense
fire("BANKFRAME_OPENED")
C_Bank.DepositMoney(Enum.BankType.Account, 200000); fire("PLAYER_MONEY"); fire("ACCOUNT_MONEY")
local e = last()
check("deposit logged as transfer", e.type == "transfer" and e.direction == "deposit" and e.source == "bank" and e.amount == 200000)
local today = Data:GetDailySummary()
check("deposit not counted as expense", today.income == 0 and today.expense == 0)
check("session unaffected", Tracker:GetSessionStats().expense == 0)
check("callback got transfer", notified[#notified] == "transfer:bank")
check("warband balance cached (700000)", Data:GetWarbandBankMoney() == 700000)
check("UI refresh emitted", uiRefreshes >= 2)

-- 2. Withdrawal
C_Bank.WithdrawMoney(Enum.BankType.Account, 50000); fire("PLAYER_MONEY"); fire("ACCOUNT_MONEY")
e = last()
check("withdraw logged as transfer", e.type == "transfer" and e.direction == "withdraw" and e.amount == 50000)
check("withdraw not counted as income", Data:GetDailySummary().income == 0)
check("warband balance updated (650000)", Data:GetWarbandBankMoney() == 650000)

-- 3. Other spending at the bank (e.g. tab purchase) is a real expense labelled Bank
money = money - 10000; fire("PLAYER_MONEY")
e = last()
check("bank tab purchase is expense/bank", e.type == "expense" and e.source == "bank")
fire("BANKFRAME_CLOSED")

-- 4. Guild bank deposit: expense labelled guild bank
fire("GUILDBANKFRAME_OPENED")
DepositGuildBankMoney(30000); fire("PLAYER_MONEY")
e = last()
check("guild deposit is expense/guildbank", e.type == "expense" and e.source == "guildbank" and e.amount == 30000)
fire("GUILDBANKFRAME_CLOSED")

-- 5. Stale hook doesn't swallow a later unrelated change
C_Bank.DepositMoney(Enum.BankType.Account, 1)  -- captured but PLAYER_MONEY never "arrives" for it
money = money + 1 -- undo the mock move so no delta
now = now + 60
money = money - 1; fire("PLAYER_MONEY")
e = last()
check("expired bank op not matched", e.type == "expense" and e.source == "unknown")

-- 6. Plain spending elsewhere unchanged
money = money - 5000; fire("PLAYER_MONEY")
check("normal expense still 'unknown'", last().type == "expense" and last().source == "unknown")

-- 7. Aggregations tolerate transfer entries
local totals, grand = Data:GetSourceBreakdown("all")
check("breakdown excludes transfers", totals.bank.expense == 10000 and totals.bank.income == 0 and grand.expense == 10000 + 30000 + 1 + 5000)
local csv = Data:GetExportCSV()
check("CSV labels transfers", csv:find(",bank_deposit,200000,") and csv:find(",bank_withdraw,50000,"))
local f = Data:GetFilteredEntries({ entryType = "transfer" })
check("history transfer filter", f.total == 2)

-- 8. Goal includes warband bank
Data:SetGoal(money + 650000)
check("goal counts warband bank", Data:GetGoalProgress().progress == 1)
check("source locale keys", Tracker:GetSourceLocaleKey("bank") == "SRC_BANK" and ns.L["SRC_GUILDBANK"] == "Guild")

-- 9. Vendor sales are named from the buyback list
local entriesUpdated = 0
GL.Events:On("ENTRIES_UPDATED", function() entriesUpdated = entriesUpdated + 1 end)
buyback = { { "Linen Cloth", 2000, 20 } }          -- sold on an earlier visit
fire("MERCHANT_SHOW")
local function sell(name, price, qty) buyback[#buyback + 1] = { name, price, qty }; money = money + price end

-- money first, buyback list updates after
money = money + 2000; fire("PLAYER_MONEY")
local sale = last()
check("vendor sale logged before buyback update", sale.type == "income" and sale.source == "vendor" and sale.itemName == nil)
buyback[#buyback + 1] = { "Linen Cloth", 2000, 20 }; fire("MERCHANT_UPDATE")
check("named once buyback updates (identical to an older sale)", sale.itemName == "Linen Cloth (20)" and sale.quantity == 20 and sale.vendorType == "sale")
check("UI told the entry changed", entriesUpdated == 1)

-- buyback list first, money after
buyback[#buyback + 1] = { "Frostweave Cloth", 13350, 1 }; fire("MERCHANT_UPDATE")
money = money + 13350; fire("PLAYER_MONEY")
check("named immediately when buyback is already updated", last().itemName == "Frostweave Cloth" and last().quantity == 1)

-- Sell Junk: several items, one money change
buyback[#buyback + 1] = { "Broken Fang", 105, 3 }
buyback[#buyback + 1] = { "Torn Pelt", 240, 1 }
buyback[#buyback + 1] = { "Cracked Bone", 55, 2 }
buyback[#buyback + 1] = { "Frayed Rope", 10, 1 }
buyback[#buyback + 1] = { "Dull Shard", 15, 1 }
money = money + 425; fire("PLAYER_MONEY")
local junk = last()
check("sell junk names several items", junk.items and #junk.items == 5
    and junk.itemName == "Dull Shard, Frayed Rope, Cracked Bone (2) +2 more")

-- An amount with no matching item stays unnamed, then expires without blocking later sales
money = money + 777; fire("PLAYER_MONEY")
local odd = last()
now = now + 6
sell("Iron Ore", 900, 17); fire("PLAYER_MONEY")
check("unmatched sale stays unnamed", odd.itemName == nil)
check("later sale still matched after expiry", last().itemName == "Iron Ore (17)")

-- Spending at the vendor is untouched
money = money - 5000; fire("PLAYER_MONEY")
check("vendor purchase not named", last().type == "expense" and last().itemName == nil)
fire("MERCHANT_CLOSED")

-- Reopening: everything already in the list counts as old
fire("MERCHANT_SHOW")
money = money + 900; fire("PLAYER_MONEY")
check("old buyback items not reused on a new visit", last().itemName == nil)
fire("MERCHANT_CLOSED")

os.exit(fails == 0 and 0 or 1)
