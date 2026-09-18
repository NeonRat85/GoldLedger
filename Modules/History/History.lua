--[[
    Copperwise / History: History.lua
    Feature module entry point.

    Delete Modules/History/ + 3 .toc lines to uninstall.
]]

local ADDON_NAME, ns = ...
ns.History = ns.History or {}

local Copperwise = ns.Copperwise
local Module = {}
ns.History.Module = Module

if Copperwise and Copperwise.RegisterFeature then
    Copperwise:RegisterFeature("history", Module)
end

function Module:OnInitialize() end

function Module:OnEnable()
    if Copperwise.RegisterHeaderButton then
        Copperwise:RegisterHeaderButton("history", function()
            local L = ns.History.L
            return L and L["HISTORY_BUTTON"] or "History"
        end, function()
            local Frame = ns.History.Frame
            if Frame and Frame.Toggle then Frame:Toggle() end
        end)
    end

    if Copperwise.RegisterSlashCommand then
        Copperwise:RegisterSlashCommand("history", function()
            local Frame = ns.History.Frame
            if Frame and Frame.Toggle then Frame:Toggle() end
        end)
    end
end
