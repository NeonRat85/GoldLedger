--[[
    Copperwise: Locale.lua
    Pattern: Registry with __index fallback

    Loaded first. All UI strings live here (English).
    Unknown keys fall back to the key itself.
    Access: ns.L["KEY"]
]]

local ADDON_NAME, ns = ...

-------------------------------------------------------------------------------
-- Registry: UI strings
-------------------------------------------------------------------------------
local defaultStrings = {
    -- General
    ["ADDON_LOADED"]        = "|cffb87333Copperwise|r loaded. Type |cfffff569/cw|r to open.",
    ["IMPORTED_GOLDLEDGER"] = "imported %d transactions for %d characters from GoldLedger. You can disable GoldLedger now.",
    ["ADDON_TITLE"]         = "Copperwise",
    ["SLASH_HELP"]          = "Usage: /cw — toggle window, /cw reset — reset data",
    ["RESET_CONFIRM"]       = "All data for this character has been reset.",

    -- UI Headers
    ["HEADER_TODAY"]        = "Today",
    ["HEADER_YESTERDAY"]    = "Yesterday",
    ["HEADER_MONTH"]        = "This Month",
    ["HEADER_RECENT"]       = "Recent Transactions",
    ["HEADER_SESSION"]      = "Session",
    ["HEADER_INCOME"]       = "Income",
    ["HEADER_EXPENSE"]      = "Expense",
    ["HEADER_BALANCE"]      = "Balance",
    ["HEADER_NET"]          = "Net",
    ["HEADER_ON_HAND"]      = "On Hand",

    -- Tooltip
    ["TOOLTIP_TITLE"]       = "Copperwise",
    ["TOOLTIP_HINT"]        = "|cffffffffClick|r to toggle window",
    ["TOOLTIP_TODAY"]       = "Today",
    ["TOOLTIP_MONTH"]       = "This Month",
    ["TOOLTIP_TOTAL"]       = "Total",

    -- Gold formatting
    ["GOLD_ABBR"]           = "g",
    ["SILVER_ABBR"]         = "s",
    ["COPPER_ABBR"]         = "c",

    -- Time
    ["TIME_FORMAT"]         = "%H:%M",
    ["DATE_FORMAT"]         = "%Y-%m-%d",
    ["MONTH_FORMAT"]        = "%Y-%m",

    -- Messages
    ["NO_DATA"]             = "No transactions yet.",
    ["INCOME_LOGGED"]       = "+%s recorded",
    ["EXPENSE_LOGGED"]      = "-%s recorded",

    -- Chart
    ["HEADER_CHART"]        = "Daily Chart",
    ["CHART_DAY"]           = "Day %d",
    ["CHART_7D"]            = "7 days",
    ["CHART_30D"]           = "30 days",
    ["CHART_ALL"]           = "All",

    -- Filter
    ["FILTER_ALL"]          = "All",

    -- Source categories
    ["SRC_VENDOR"]          = "Vendor",
    ["SRC_AH"]              = "AH",
    ["SRC_MAIL"]            = "Mail",
    ["SRC_QUEST"]           = "Quest",
    ["SRC_LOOT"]            = "Loot",
    ["SRC_TRADE"]           = "Trade",
    ["SRC_REPAIR"]          = "Repair",
    ["SRC_UNKNOWN"]         = "Other",
    ["SRC_BANK"]            = "Bank",
    ["SRC_GUILDBANK"]       = "Guild",

    -- Warband bank
    ["WARBAND_BANK"]        = "Warband Bank",
    ["WARBAND_BANK_LINE"]   = "Warband Bank: %s",

    -- Goal
    ["HEADER_GOAL"]          = "Goal",
    ["GOAL_SET"]             = "Goal set: %s",
    ["GOAL_CLEARED"]         = "Goal cleared.",
    ["GOAL_REACHED"]         = "Goal reached!",
    ["GOAL_REMAINING"]       = "~%d days left",
    ["GOAL_TOO_FAR"]         = "Too far at this rate",
    ["GOAL_SET_BUTTON"]      = "Set goal",
    ["GOAL_CHANGE_BUTTON"]   = "Change goal",
    ["GOAL_USAGE"]           = "Usage: /cw goal <gold> | /cw goal clear",
    ["GOAL_NONE"]            = "Click to set goal",
    ["GOAL_CLICK_HINT"]      = "|cffffffffClick|r to change goal",

    -- Multi-character

    -- Export

    -- Source Breakdown

    -- Characters tabs

    -- Settings
    ["SETTINGS_BUTTON"]      = "Settings",
    ["HEADER_SETTINGS"]      = "Settings",
    ["SETTINGS_MINIMAP"]     = "Show minimap button",
    ["SETTINGS_RESET_SESSION"] = "Reset session",

    -- History
}

-------------------------------------------------------------------------------
-- Lookup: unknown keys fall back to the key itself
-------------------------------------------------------------------------------
local L = setmetatable({}, {
    __index = function(_, key)
        return defaultStrings[key] or key
    end
})

-------------------------------------------------------------------------------
-- Export to addon namespace
-------------------------------------------------------------------------------
ns.L = L
