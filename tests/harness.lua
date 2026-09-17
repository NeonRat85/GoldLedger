-- Minimal WoW API stub that loads GoldLedger's real Locale/Core/Data/Tracker and
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
print = print

-- ---- Load the addon's real core files ----------------------------------------
local ns = {}
for _, f in ipairs({ "Locale.lua", "Core.lua", "Data.lua", "Tracker.lua" }) do
  local chunk = assert(loadfile(dir .. "/" .. f))
  chunk("GoldLedger", ns)
end
fire("ADDON_LOADED", "GoldLedger")
fire("PLAYER_LOGIN")

local GL = ns.GoldLedger
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

os.exit(fails == 0 and 0 or 1)
