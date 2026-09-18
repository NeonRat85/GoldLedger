--[[
    Copperwise: UI/Settings.lua
    Settings popup: theme, language, minimap toggle, reset session.
    Uses ONLY UI public API — no direct WoW frame creation.
]]

local ADDON_NAME, ns = ...
local Copperwise = ns.Copperwise
local L = ns.L

local function UI()      return Copperwise and Copperwise:GetModule("UI") end
local function Helpers() return ns.UI_Helpers end
local function TC(key)
    local h = Helpers()
    if h and h.TC then return h.TC(key) end
    return 1, 1, 1, 1
end

local settingsFrame
local settingsElements = {}
local RefreshSettings

local function CreateSettingsFrame()
    if settingsFrame then return end
    local ui = UI()
    if not ui then return end

    local f = ui:CreatePopup({
        name  = "CopperwiseSettingsFrame",
        title = L and L["HEADER_SETTINGS"] or "Settings",
        width = 320, height = 124,
    })
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)

    -- Minimap label + checkbox (theme selector removed — native WoW look fixed)
    local y = -40
    local minimapLabel = ui:CreateLabel(f, { color = "LABEL" })
    minimapLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    settingsElements.minimapLabel = minimapLabel

    local minimapCheck = ui:CreateCheckbox(f, {
        onChange = function(checked)
            if _G.CopperwiseDB and _G.CopperwiseDB.settings then
                _G.CopperwiseDB.settings.showMinimap = checked
            end
            if ns.Minimap and ns.Minimap.SetVisible then
                ns.Minimap.SetVisible(checked)
            end
        end,
    })
    minimapCheck:SetPoint("LEFT", minimapLabel, "RIGHT", 6, 0)
    settingsElements.minimapCheck = minimapCheck
    f.minimapCheck = minimapCheck  -- expose for tests and external code

    y = y - 36

    -- Reset session button
    local resetBtn = ui:CreateButton(f, {
        width = 140, height = 24,
        onClick = function()
            local Tracker = Copperwise:GetModule("Tracker")
            if Tracker and Tracker.ResetSession then Tracker:ResetSession() end
            -- Refresh visible totals (MainFrame listens internally)
            if Copperwise and Copperwise.Events then
                Copperwise.Events:Emit("SESSION_RESET")
            end
            settingsFrame:Hide()
        end,
    })
    resetBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    settingsElements.resetBtn = resetBtn

    settingsFrame = f
end

RefreshSettings = function()
    if not settingsFrame then CreateSettingsFrame() end
    local f = settingsFrame
    local Themes = Copperwise:GetModule("Themes")

    if f.SetBackdropColor and f.GetBackdrop and f:GetBackdrop() then
        f:SetBackdropColor(TC("FRAME_BG"))
        f:SetBackdropBorderColor(TC("BORDER"))
    end

    if f.title and L then f.title:SetText(L["HEADER_SETTINGS"]) end

    settingsElements.minimapLabel:SetText(L["SETTINGS_MINIMAP"])
    settingsElements.minimapCheck:SetChecked(
        _G.CopperwiseDB and _G.CopperwiseDB.settings
            and _G.CopperwiseDB.settings.showMinimap ~= false
    )

    settingsElements.resetBtn:SetText(L["SETTINGS_RESET_SESSION"])
    if settingsElements.resetBtn.text and settingsElements.resetBtn.text.SetTextColor then
        settingsElements.resetBtn.text:SetTextColor(1, 0.3, 0.3)
    end
end

-------------------------------------------------------------------------------
-- Export
-------------------------------------------------------------------------------
ns.UI_Settings = {
    Create = CreateSettingsFrame,
    Refresh = RefreshSettings,
    GetFrame = function() return settingsFrame end,
}
