--[[
    Copperwise / History: Locale.lua
    Self-contained localization for this module.
]]

local ADDON_NAME, ns = ...
ns.History = ns.History or {}

local enUS = {
    HISTORY_BUTTON       = "History",
    HISTORY_TITLE        = "Transaction History",
    HISTORY_PAGE         = "Page %d/%d",
    HISTORY_SHOWING      = "Showing %d-%d of %d",
    HISTORY_MIN_AMOUNT   = "Min gold:",
    HISTORY_TYPE_ALL     = "All",
    HISTORY_TYPE_INCOME  = "Income",
    HISTORY_TYPE_EXPENSE = "Expense",
    HISTORY_TYPE_TRANSFER = "Bank Transfer",
    HISTORY_NO_RESULTS   = "No transactions match filters.",
    HISTORY_PREV         = "< Prev",
    HISTORY_NEXT         = "Next >",
}

-- English only; unknown keys fall back to the key itself
local L = setmetatable({}, { __index = function(_, key) return enUS[key] or key end })

ns.History.L = L
