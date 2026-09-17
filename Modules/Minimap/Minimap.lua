--[[
    GoldLedger / Minimap: Minimap.lua
    Minimap button via LibDataBroker-1.1 + LibDBIcon-1.0: summary tooltip,
    click-to-toggle, drag-to-reposition (handled by LibDBIcon).
    Self-contained feature module.
]]

local ADDON_NAME, ns = ...
ns.Minimap = ns.Minimap or {}

local GoldLedger = ns.GoldLedger
local L = ns.L  -- core locale for tooltip strings (TOOLTIP_TITLE etc — kept in core Locale)

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

local Module = {}
ns.Minimap.Module = Module

if GoldLedger and GoldLedger.RegisterFeature then
    GoldLedger:RegisterFeature("minimap", Module)
end

local function T(key)
    local Themes = GoldLedger and GoldLedger:GetModule("Themes")
    if Themes and Themes.GetColor then return Themes:GetColor(key) end
    return { 1, 1, 1 }
end

--- Adds "label ........ value" with the label in LABEL colour and value in valueKey colour
local function AddValueLine(tooltip, label, text, valueKey)
    local lc, vc = T("LABEL"), T(valueKey)
    tooltip:AddDoubleLine(label, text, lc[1], lc[2], lc[3], vc[1], vc[2], vc[3])
end

local function OnTooltipShow(tooltip)
    tooltip:AddLine(L and L["TOOLTIP_TITLE"] or "GoldLedger", 1, 0.84, 0)

    local helpers = ns.UI_Helpers
    local GoldFormatter = helpers and helpers.GoldFormatter
    local Data = GoldLedger and GoldLedger:GetModule("Data")
    if Data and GoldFormatter then
        local today = Data:GetDailySummary()
        tooltip:AddLine(" ")
        tooltip:AddLine(L and L["TOOLTIP_TODAY"] or "Today", 1, 1, 1)
        AddValueLine(tooltip, L and L["HEADER_INCOME"] or "Income", GoldFormatter.Full(today.income), "INCOME")
        AddValueLine(tooltip, L and L["HEADER_EXPENSE"] or "Expense", GoldFormatter.Full(today.expense), "EXPENSE")

        local month = Data:GetMonthlySummary()
        tooltip:AddLine(" ")
        tooltip:AddLine(L and L["TOOLTIP_MONTH"] or "This Month", 1, 1, 1)
        AddValueLine(tooltip, L and L["HEADER_INCOME"] or "Income", GoldFormatter.Full(month.income), "INCOME")
        AddValueLine(tooltip, L and L["HEADER_EXPENSE"] or "Expense", GoldFormatter.Full(month.expense), "EXPENSE")

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
    icon = "Interface\\Icons\\INV_Misc_Coin_01",
    OnClick = function()
        local UI = GoldLedger and GoldLedger:GetModule("UI")
        if UI and UI.ToggleMainFrame then UI:ToggleMainFrame() end
    end,
    OnTooltipShow = OnTooltipShow,
})
ns.Minimap.DataObject = dataObject

--- LibDBIcon's saved state ({ hide, minimapPos }) in GoldLedgerDB.settings.minimap.
--- Migrates the pre-LibDBIcon keys (minimapPos, showMinimap, minimapHidden) once.
local function GetIconDB()
    local settings = _G.GoldLedgerDB and _G.GoldLedgerDB.settings
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
    _G.GoldLedgerDB.settings.showMinimap = visible and true or false
    if not LDBIcon:IsRegistered(ADDON_NAME) then return end
    if visible then LDBIcon:Show(ADDON_NAME) else LDBIcon:Hide(ADDON_NAME) end
end
