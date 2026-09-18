local ADDON_NAME, ns = ...
ns.Characters = ns.Characters or {}

local enUS = {
    CHARS_BUTTON        = "Characters",
    CHARS_TITLE         = "Characters",
    CHARS_ACCOUNT_TOTAL = "Account Total",
    CHARS_DAY_LABEL     = "Today",
    CHARS_WEEK_LABEL    = "This Week",
    CHARS_MONTH_LABEL   = "This month",
}

-- English only; unknown keys fall back to the key itself
local L = setmetatable({}, { __index = function(_, key) return enUS[key] or key end })

ns.Characters.L = L
