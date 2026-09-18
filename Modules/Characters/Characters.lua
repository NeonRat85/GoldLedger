local ADDON_NAME, ns = ...
ns.Characters = ns.Characters or {}

local Copperwise = ns.Copperwise
local Module = {}
ns.Characters.Module = Module

if Copperwise and Copperwise.RegisterFeature then
    Copperwise:RegisterFeature("characters", Module)
end

function Module:OnInitialize() end

function Module:OnEnable()
    if Copperwise.RegisterHeaderButton then
        Copperwise:RegisterHeaderButton("characters", function()
            local L = ns.Characters.L
            return L and L["CHARS_BUTTON"] or "Characters"
        end, function()
            local Frame = ns.Characters.Frame
            if Frame and Frame.Toggle then Frame:Toggle() end
        end)
    end

    if Copperwise.RegisterSlashCommand then
        Copperwise:RegisterSlashCommand("chars", function()
            local Frame = ns.Characters.Frame
            if Frame and Frame.Toggle then Frame:Toggle() end
        end)
    end
end
