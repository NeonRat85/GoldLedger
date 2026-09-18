local ADDON_NAME, ns = ...
ns.Breakdown = ns.Breakdown or {}

local enUS = {
    BREAKDOWN_BUTTON = "Summary",
    BREAKDOWN_TITLE  = "Source Breakdown",
    BREAKDOWN_TODAY  = "Today",
    BREAKDOWN_WEEK   = "Week",
    BREAKDOWN_MONTH  = "Month",
    BREAKDOWN_ALL    = "All",
    BREAKDOWN_TOTAL  = "Total",
    BREAKDOWN_SOURCE = "Source",
}

-- English only; unknown keys fall back to the key itself
local L = setmetatable({}, { __index = function(_, key) return enUS[key] or key end })

ns.Breakdown.L = L
