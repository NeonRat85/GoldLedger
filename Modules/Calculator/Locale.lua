--[[
    Copperwise / Calculator: Locale.lua
    Self-contained localization for this module.
]]

local ADDON_NAME, ns = ...
ns.Calculator = ns.Calculator or {}

local enUS = {
    CALC_BUTTON    = "Calculator",
    CALC_TITLE     = "Calculator",
    CALC_CLEAR     = "C",
}

-- English only; unknown keys fall back to the key itself
local L = setmetatable({}, { __index = function(_, key) return enUS[key] or key end })

ns.Calculator.L = L
