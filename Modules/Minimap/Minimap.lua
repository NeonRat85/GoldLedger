--[[
    Copperwise / Minimap: Minimap.lua
    Minimap button via LibDataBroker-1.1 + LibDBIcon-1.0: summary tooltip,
    click-to-toggle, drag-to-reposition (handled by LibDBIcon).
    Self-contained feature module.
]]

local ADDON_NAME, ns = ...
ns.Minimap = ns.Minimap or {}

local Copperwise = ns.Copperwise
local L = ns.L  -- core locale for tooltip strings (TOOLTIP_TITLE etc — kept in core Locale)

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

local Module = {}
ns.Minimap.Module = Module

if Copperwise and Copperwise.RegisterFeature then
    Copperwise:RegisterFeature("minimap", Module)
end

local function T(key)
    local Themes = Copperwise and Copperwise:GetModule("Themes")
    if Themes and Themes.GetColor then return Themes:GetColor(key) end
    return { 1, 1, 1 }
end

--- Adds "label ........ value" with the label in LABEL colour and value in valueKey colour
local function AddValueLine(tooltip, label, text, valueKey)
    local lc, vc = T("LABEL"), T(valueKey)
    tooltip:AddDoubleLine(label, text, lc[1], lc[2], lc[3], vc[1], vc[2], vc[3])
end

--- Income, expense and their total (net) for one period
local function AddPeriodLines(tooltip, summary, GoldFormatter)
    AddValueLine(tooltip, L and L["HEADER_INCOME"] or "Income", GoldFormatter.Full(summary.income), "INCOME")
    AddValueLine(tooltip, L and L["HEADER_EXPENSE"] or "Expense", GoldFormatter.Full(summary.expense), "EXPENSE")
    local net = summary.income - summary.expense
    AddValueLine(tooltip, L and L["TOOLTIP_TOTAL"] or "Total",
        (net < 0 and "-" or "+") .. GoldFormatter.Full(net),
        net < 0 and "BALANCE_NEG" or "BALANCE_POS")
end

local function OnTooltipShow(tooltip)
    tooltip:AddLine(L and L["TOOLTIP_TITLE"] or "Copperwise", 0.85, 0.53, 0.30)  -- copper

    local helpers = ns.UI_Helpers
    local GoldFormatter = helpers and helpers.GoldFormatter
    local Data = Copperwise and Copperwise:GetModule("Data")
    if Data and GoldFormatter then
        local today = Data:GetDailySummary()
        tooltip:AddLine(" ")
        tooltip:AddLine(L and L["TOOLTIP_TODAY"] or "Today", 1, 1, 1)
        AddPeriodLines(tooltip, today, GoldFormatter)

        local month = Data:GetMonthlySummary()
        tooltip:AddLine(" ")
        tooltip:AddLine(L and L["TOOLTIP_MONTH"] or "This Month", 1, 1, 1)
        AddPeriodLines(tooltip, month, GoldFormatter)

        tooltip:AddLine(" ")
        AddValueLine(tooltip, L and L["WARBAND_BANK"] or "Warband Bank",
            GoldFormatter.Full(Data:GetWarbandBankMoney()), "TRANSFER")
    end

    tooltip:AddLine(" ")
    tooltip:AddLine(L and L["TOOLTIP_HINT"] or "", 0.5, 0.5, 0.5)
end

local dataObject = LDB:NewDataObject(ADDON_NAME, {
    type = "launcher",
    text = ADDON_NAME,
    icon = "Interface\\Icons\\INV_Misc_Coin_05",
    OnClick = function()
        local UI = Copperwise and Copperwise:GetModule("UI")
        if UI and UI.ToggleMainFrame then UI:ToggleMainFrame() end
    end,
    OnTooltipShow = OnTooltipShow,
})
ns.Minimap.DataObject = dataObject

--- LibDBIcon's saved state ({ hide, minimapPos }) in CopperwiseDB.settings.minimap.
--- Migrates the pre-LibDBIcon keys (minimapPos, showMinimap, minimapHidden) once.
local function GetIconDB()
    local settings = _G.CopperwiseDB and _G.CopperwiseDB.settings
    if not settings then return nil end
    if type(settings.minimap) ~= "table" then
        settings.minimap = {
            minimapPos = settings.minimapPos or 225,
            hide = settings.showMinimap == false or settings.minimapHidden == true,
        }
        settings.showMinimap = not settings.minimap.hide
        settings.minimapPos = nil
        settings.minimapHidden = nil
    end
    return settings.minimap
end

function Module:OnInitialize() end

function Module:OnEnable()
    local db = GetIconDB()
    if not db or LDBIcon:IsRegistered(ADDON_NAME) then return end
    LDBIcon:Register(ADDON_NAME, dataObject, db)
    ns.Minimap.Button = LDBIcon:GetMinimapButton(ADDON_NAME)
end

--- Public: show/hide minimap button (used by Settings popup)
function ns.Minimap.SetVisible(visible)
    local db = GetIconDB()
    if not db then return end
    db.hide = not visible
    _G.CopperwiseDB.settings.showMinimap = visible and true or false
    if not LDBIcon:IsRegistered(ADDON_NAME) then return end
    if visible then LDBIcon:Show(ADDON_NAME) else LDBIcon:Hide(ADDON_NAME) end
end
