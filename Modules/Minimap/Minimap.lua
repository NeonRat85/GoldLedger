--[[
    GoldLedger / Minimap: Minimap.lua
    Minimap button with summary tooltip + drag-to-reposition + click-to-toggle.
    Self-contained feature module.
]]

local ADDON_NAME, ns = ...
ns.Minimap = ns.Minimap or {}

local GoldLedger = ns.GoldLedger
local L = ns.L  -- core locale for tooltip strings (TOOLTIP_TITLE etc — kept in core Locale)

local Module = {}
ns.Minimap.Module = Module
local minimapButton

if GoldLedger and GoldLedger.RegisterFeature then
    GoldLedger:RegisterFeature("minimap", Module)
end

local function T(key)
    local Themes = GoldLedger and GoldLedger:GetModule("Themes")
    if Themes and Themes.GetColor then return Themes:GetColor(key) end
    return { 1, 1, 1 }
end

local function CreateButton()
    local helpers = ns.UI_Helpers
    local GoldFormatter = helpers and helpers.GoldFormatter

    -- Layout and layering follow LibDBIcon-1.0 (retail), which the minimap
    -- buttons of most other addons use.
    local button = CreateFrame("Button", "GoldLedgerMinimapButton", Minimap)
    button:SetSize(31, 31)
    -- Fixed strata/level: the button is parented to Minimap, whose cluster is
    -- LOW strata and toplevel. Without these, a Raise() or strata change on an
    -- ancestor re-layers the button under the minimap, which then takes the mouse.
    button:SetFrameStrata("MEDIUM")
    button:SetFixedFrameStrata(true)
    button:SetFrameLevel(8)
    button:SetFixedFrameLevel(true)
    button:RegisterForClicks("AnyUp")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")

    -- The ring sits in the top-left of this texture; 50px lines it up with the 31px hit area
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")

    local function UpdatePosition(angle)
        local rad = math.rad(angle)
        local radius = (Minimap:GetWidth() / 2) + 5
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(rad) * radius,
            math.sin(rad) * radius
        )
    end

    -- Angle from the minimap centre to the cursor, in Minimap's own coordinate
    -- space (the minimap can be scaled independently of UIParent in Edit Mode)
    local function CursorAngle()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        return math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
    end

    local function OnDragUpdate()
        UpdatePosition(CursorAngle())
    end

    button:RegisterForDrag("LeftButton")

    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        if GameTooltip then GameTooltip:Hide() end
        self:SetScript("OnUpdate", OnDragUpdate)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
        local angle = CursorAngle()
        if _G.GoldLedgerDB and _G.GoldLedgerDB.settings then
            _G.GoldLedgerDB.settings.minimapPos = angle
        end
        UpdatePosition(angle)
    end)

    button:SetScript("OnClick", function()
        local UI = GoldLedger and GoldLedger:GetModule("UI")
        if UI and UI.ToggleMainFrame then UI:ToggleMainFrame() end
    end)

    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L and L["TOOLTIP_TITLE"] or "GoldLedger", 1, 0.84, 0)

        local Data = GoldLedger and GoldLedger:GetModule("Data")
        if Data and GoldFormatter then
            local today = Data:GetDailySummary()
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L and L["TOOLTIP_TODAY"] or "Today", 1, 1, 1)
            GameTooltip:AddDoubleLine(
                L and L["HEADER_INCOME"] or "Income", GoldFormatter.Full(today.income),
                T("LABEL")[1], T("LABEL")[2], T("LABEL")[3],
                T("INCOME")[1], T("INCOME")[2], T("INCOME")[3])
            GameTooltip:AddDoubleLine(
                L and L["HEADER_EXPENSE"] or "Expense", GoldFormatter.Full(today.expense),
                T("LABEL")[1], T("LABEL")[2], T("LABEL")[3],
                T("EXPENSE")[1], T("EXPENSE")[2], T("EXPENSE")[3])

            local month = Data:GetMonthlySummary()
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L and L["TOOLTIP_MONTH"] or "This Month", 1, 1, 1)
            GameTooltip:AddDoubleLine(
                L and L["HEADER_INCOME"] or "Income", GoldFormatter.Full(month.income),
                T("LABEL")[1], T("LABEL")[2], T("LABEL")[3],
                T("INCOME")[1], T("INCOME")[2], T("INCOME")[3])
            GameTooltip:AddDoubleLine(
                L and L["HEADER_EXPENSE"] or "Expense", GoldFormatter.Full(month.expense),
                T("LABEL")[1], T("LABEL")[2], T("LABEL")[3],
                T("EXPENSE")[1], T("EXPENSE")[2], T("EXPENSE")[3])

            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(
                L and L["WARBAND_BANK"] or "Warband Bank", GoldFormatter.Full(Data:GetWarbandBankMoney()),
                T("LABEL")[1], T("LABEL")[2], T("LABEL")[3],
                T("TRANSFER")[1], T("TRANSFER")[2], T("TRANSFER")[3])
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L and L["TOOLTIP_HINT"] or "", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    local settings = _G.GoldLedgerDB and _G.GoldLedgerDB.settings
    UpdatePosition(settings and settings.minimapPos or 225)

    minimapButton = button
    ns.Minimap.Button = button
    return button
end

function Module:OnInitialize() end

function Module:OnEnable()
    if not minimapButton then CreateButton() end
    -- Respect persisted visibility
    local settings = _G.GoldLedgerDB and _G.GoldLedgerDB.settings
    if settings and settings.minimapHidden then
        minimapButton:Hide()
    end
end

--- Public: show/hide minimap button (used by Settings popup)
function ns.Minimap.SetVisible(visible)
    if not minimapButton then return end
    if visible then minimapButton:Show() else minimapButton:Hide() end
    if _G.GoldLedgerDB and _G.GoldLedgerDB.settings then
        _G.GoldLedgerDB.settings.minimapHidden = not visible
    end
end
