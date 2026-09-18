--[[
    Copperwise / Breakdown: Breakdown.lua
    Feature module entry point.
    Note: Breakdown has NO header button — it's opened from MainFrame's "Summary" card button.
]]

local ADDON_NAME, ns = ...
ns.Breakdown = ns.Breakdown or {}

local Copperwise = ns.Copperwise
local Module = {}
ns.Breakdown.Module = Module

if Copperwise and Copperwise.RegisterFeature then
    Copperwise:RegisterFeature("breakdown", Module)
end

function Module:OnInitialize() end

function Module:OnEnable()
    if Copperwise.RegisterSlashCommand then
        Copperwise:RegisterSlashCommand("breakdown", function()
            local Frame = ns.Breakdown.Frame
            if Frame and Frame.Toggle then Frame:Toggle() end
        end)
    end
end
