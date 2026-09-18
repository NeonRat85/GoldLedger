--[[
    Copperwise / Calculator: Calculator.lua
    Feature module entry point.

    Uses core's modular API:
      - Copperwise:RegisterFeature("calculator", module)  — lifecycle
      - Copperwise:RegisterHeaderButton(name, label, fn)   — button in main frame
      - Copperwise:RegisterSlashCommand("calc", fn)        — /cw calc

    To uninstall: delete Modules/Calculator/ + 3 lines from .toc.
]]

local ADDON_NAME, ns = ...
ns.Calculator = ns.Calculator or {}

local Copperwise = ns.Copperwise
local Module = {}
ns.Calculator.Module = Module

-------------------------------------------------------------------------------
-- Feature registration
-------------------------------------------------------------------------------
if Copperwise and Copperwise.RegisterFeature then
    Copperwise:RegisterFeature("calculator", Module)
end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------
function Module:OnInitialize()
    -- Nothing to init — frame is created lazily on first Toggle
end

function Module:OnEnable()
    -- Register header button (dynamic label — updates on language switch)
    if Copperwise.RegisterHeaderButton then
        Copperwise:RegisterHeaderButton("calculator", function()
            local L = ns.Calculator.L
            local label = L and L["CALC_BUTTON"] or "Calculator"
            -- Embed calculator icon in label
            return "|TInterface\\AddOns\\Copperwise\\Modules\\Calculator\\calc_icon:12:12|t " .. label
        end, function()
            local Frame = ns.Calculator.Frame
            if Frame and Frame.Toggle then Frame:Toggle() end
        end)
    end

    -- Register slash subcommand: /cw calc
    if Copperwise.RegisterSlashCommand then
        Copperwise:RegisterSlashCommand("calc", function()
            local Frame = ns.Calculator.Frame
            if Frame and Frame.Toggle then Frame:Toggle() end
        end)
    end
end
