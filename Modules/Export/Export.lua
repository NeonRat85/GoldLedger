local ADDON_NAME, ns = ...
ns.Export = ns.Export or {}

local Copperwise = ns.Copperwise
local Module = {}
ns.Export.Module = Module

if Copperwise and Copperwise.RegisterFeature then
    Copperwise:RegisterFeature("export", Module)
end

function Module:OnInitialize() end

function Module:OnEnable()
    if Copperwise.RegisterHeaderButton then
        Copperwise:RegisterHeaderButton("export", function()
            local L = ns.Export.L
            return L and L["EXPORT_BUTTON"] or "Export"
        end, function()
            local Frame = ns.Export.Frame
            if Frame and Frame.Show then Frame:Show() end
        end)
    end

    if Copperwise.RegisterSlashCommand then
        Copperwise:RegisterSlashCommand("export", function()
            local Frame = ns.Export.Frame
            if Frame and Frame.Show then Frame:Show() end
        end)
    end
end
