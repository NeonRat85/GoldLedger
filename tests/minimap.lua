-- Loads the embedded LibStub/CallbackHandler/LibDataBroker/LibDBIcon and the Minimap
-- module against a generic widget stub, then drives registration, the tooltip,
-- click, visibility toggles and migration of pre-LibDBIcon settings.
-- Usage: luajit tests/minimap.lua [addon directory]

local dir = ... or "."
local failures = 0
local function check(label, ok)
    print((ok and "PASS " or "FAIL ") .. label)
    if not ok then failures = failures + 1 end
end

-- Generic widget: scripts are stored, Show/Hide/IsShown tracked, everything else is a no-op
local function widget(name, parent)
    local w = { scripts = {}, shown = true, name = name, parent = parent }
    return setmetatable(w, { __index = function(_, k)
        if k == "SetScript" then return function(self, n, fn) self.scripts[n] = fn end end
        if k == "HookScript" then return function(self, n, fn) self.scripts[n] = fn end end
        if k == "GetScript" then return function(self, n) return self.scripts[n] end end
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false end end
        if k == "IsShown" then return function(self) return self.shown end end
        if k == "GetName" then return function(self) return self.name end end
        if k == "GetParent" then return function(self) return self.parent end end
        if k == "CreateTexture" or k == "CreateFontString" or k == "CreateAnimationGroup"
            or k == "CreateAnimation" then
            return function(self) return widget(nil, self) end
        end
        if k == "GetWidth" or k == "GetHeight" then return function() return 198 end end
        if k == "GetCenter" then return function() return 500, 500 end end
        if k == "GetEffectiveScale" then return function() return 1 end end
        return function() end
    end })
end

local frames = {}
function CreateFrame(_, name, parent)
    local w = widget(name, parent)
    if name then _G[name] = w end
    frames[#frames + 1] = w
    return w
end
local function firePlayerLogin()
    for _, f in ipairs(frames) do
        if f.scripts.OnEvent then f.scripts.OnEvent(f, "PLAYER_LOGIN") end
    end
end
Minimap = widget("Minimap")
UIParent = widget("UIParent")
local tooltipLines = {}
GameTooltip = widget("GameTooltip")
function GameTooltip.AddLine(_, text) tooltipLines[#tooltipLines + 1] = text end
function GameTooltip.AddDoubleLine(_, left, right) tooltipLines[#tooltipLines + 1] = left .. "=" .. right end
function GetCursorPosition() return 0, 0 end
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
function geterrorhandler() return function(e) error(e, 2) end end
function hooksecurefunc() end
C_AddOns = { GetAddOnMetadata = function() return nil end }
strmatch = string.match
securecallfunction = function(fn, ...) return fn(...) end

local function load(path, ...) return assert(loadfile(dir .. "/" .. path))(...) end
load("Libs/LibStub/LibStub.lua")
load("Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
load("Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua")
load("Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua")

local toggled = 0
local ns = {
    L = setmetatable({}, { __index = function(_, k) return k end }),
    UI_Helpers = { GoldFormatter = { Full = function(c) return tostring(c) end } },
}
ns.GoldLedger = {
    RegisterFeature = function(_, _, m) ns.feature = m end,
    GetModule = function(_, name)
        if name == "Themes" then return { GetColor = function() return { 1, 1, 1 } end } end
        if name == "UI" then return { ToggleMainFrame = function() toggled = toggled + 1 end } end
        if name == "Data" then return {
            GetDailySummary = function() return { income = 11, expense = 22 } end,
            GetMonthlySummary = function() return { income = 33, expense = 44 } end,
            GetWarbandBankMoney = function() return 55 end,
        } end
    end,
}

-- Pre-LibDBIcon settings from 2.5.0: hidden via the old module's key, custom position
GoldLedgerDB = { settings = { minimapPos = 55.9, showMinimap = true, minimapHidden = true } }
load("Modules/Minimap/Minimap.lua", "GoldLedger", ns)

local LDBIcon = LibStub("LibDBIcon-1.0")
local db = GoldLedgerDB.settings
check("data object registered with LibDataBroker", LibStub("LibDataBroker-1.1"):GetDataObjectByName("GoldLedger") ~= nil)

-- In game both GoldLedger and LibDBIcon handle PLAYER_LOGIN; here GoldLedger registers
-- first, so LibDBIcon applies the saved position/visibility when its handler runs.
ns.feature:OnEnable()
firePlayerLogin()
check("registered with LibDBIcon", LDBIcon:IsRegistered("GoldLedger"))
check("migrated position", db.minimap and db.minimap.minimapPos == 55.9)
check("migrated hidden state", db.minimap.hide == true and db.showMinimap == false)
check("old keys removed", db.minimapPos == nil and db.minimapHidden == nil)

local button = LDBIcon:GetMinimapButton("GoldLedger")
check("button created", button ~= nil)
check("button starts hidden", button and not button.shown)

ns.Minimap.SetVisible(true)
check("SetVisible(true) shows and saves", button.shown and db.minimap.hide == false and db.showMinimap == true)
ns.Minimap.SetVisible(false)
check("SetVisible(false) hides and saves", not button.shown and db.minimap.hide == true and db.showMinimap == false)
ns.Minimap.SetVisible(true)

local dataObject = ns.Minimap.DataObject
dataObject.OnTooltipShow(GameTooltip)
local text = table.concat(tooltipLines, "|")
check("tooltip has today/month/bank values",
    text:find("HEADER_INCOME=11", 1, true) and text:find("HEADER_EXPENSE=44", 1, true)
    and text:find("WARBAND_BANK=55", 1, true))

dataObject.OnClick(button, "LeftButton")
check("click toggles main window", toggled == 1)

-- Enabling twice must not re-register
ns.feature:OnEnable()
check("second OnEnable is a no-op", LDBIcon:IsRegistered("GoldLedger"))

-- Fresh install, registering after LibDBIcon has already seen PLAYER_LOGIN
LDBIcon.objects = {}
GoldLedgerDB = { settings = { showMinimap = true } }
ns.feature:OnEnable()
local fresh = LDBIcon:GetMinimapButton("GoldLedger")
local m = GoldLedgerDB.settings.minimap
check("fresh install defaults", m.minimapPos == 225 and m.hide == false)
check("fresh install button shown", fresh and fresh.shown)

print(failures == 0 and "all minimap checks passed" or (failures .. " minimap check(s) failed"))
os.exit(failures == 0 and 0 or 1)
