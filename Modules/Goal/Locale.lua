local ADDON_NAME, ns = ...
ns.Goal = ns.Goal or {}

local enUS = {
    GOAL_INPUT_TEXT = "Enter goal amount in gold:",
    GOAL_CLEAR_BTN  = "Clear",
}

-- English only; unknown keys fall back to the key itself
local L = setmetatable({}, { __index = function(_, key) return enUS[key] or key end })

ns.Goal.L = L
