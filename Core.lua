--[[
    Copperwise: Core.lua
    Patterns: Module, Observer (Event Bus), Singleton

    Addon core:
    - Module system for registering and accessing modules
    - Event bus with a dispatch table (Observer pattern)
    - Slash commands /cw and /copperwise
    - Initialisation on ADDON_LOADED
]]

local ADDON_NAME, ns = ...
local L = ns.L

-------------------------------------------------------------------------------
-- Singleton: the addon's global namespace
-------------------------------------------------------------------------------
local Copperwise = {}
Copperwise.name = ADDON_NAME
Copperwise.version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "1.0.0"

-- Export to global and namespace
_G.Copperwise = Copperwise
ns.Copperwise = Copperwise

-------------------------------------------------------------------------------
-- Module Pattern: registering and accessing modules
-------------------------------------------------------------------------------
local modules = {}

--- Registers a module
--- @param name string Module name
--- @param module table Module table
function Copperwise:RegisterModule(name, module)
    if modules[name] then
        error(("Copperwise: Module '%s' already registered"):format(name))
    end
    modules[name] = module
    module.name = name
    return module
end

--- Returns a registered module
--- @param name string Module name
--- @return table|nil
function Copperwise:GetModule(name)
    return modules[name]
end

--- Calls a method on every module that has it
--- @param method string Method name
--- @param ... any Arguments
function Copperwise:CallModules(method, ...)
    for _, mod in pairs(modules) do
        if type(mod[method]) == "function" then
            mod[method](mod, ...)
        end
    end
end

-------------------------------------------------------------------------------
-- Observer Pattern: event bus with a dispatch table
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local eventHandlers = {} -- { [event] = { callback1, callback2, ... } }

--- Registers a handler for a WoW event
--- @param event string WoW event name
--- @param callback function Handler
function Copperwise:RegisterEvent(event, callback)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(eventHandlers[event], callback)
end

--- Removes all handlers for an event
--- @param event string WoW event name
function Copperwise:UnregisterEvent(event)
    eventHandlers[event] = nil
    eventFrame:UnregisterEvent(event)
end

-- Central dispatch: one OnEvent for every event
eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = eventHandlers[event]
    if handlers then
        for _, callback in ipairs(handlers) do
            callback(event, ...)
        end
    end
end)

-------------------------------------------------------------------------------
-- Internal Event Bus: Copperwise.Events:On/Off/Emit for cross-module messages
-------------------------------------------------------------------------------
local busSubscribers = {}  -- { [event_name] = { fn1, fn2, ... } }

Copperwise.Events = {}

function Copperwise.Events:On(name, handler)
    busSubscribers[name] = busSubscribers[name] or {}
    table.insert(busSubscribers[name], handler)
    return handler
end

function Copperwise.Events:Off(name, handler)
    local list = busSubscribers[name]
    if not list then return end
    for i, fn in ipairs(list) do
        if fn == handler then table.remove(list, i) return end
    end
end

--- Public wrapper: register a handler for a WoW-native event (PLAYER_MONEY etc.)
--- Equivalent to Copperwise:RegisterEvent but on the Events namespace for discoverability.
function Copperwise.Events:RegisterWoWEvent(event, handler)
    return Copperwise:RegisterEvent(event, handler)
end

function Copperwise.Events:Emit(name, data)
    local list = busSubscribers[name]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, data)
        if not ok then
            Copperwise:Debug("Events", "subscriber error on", name, "→", tostring(err))
        end
    end
end

-------------------------------------------------------------------------------
-- CreateLocale: helper to build a string table for feature modules
-- Usage: local L = Copperwise:CreateLocale({ enUS = {...} })
-------------------------------------------------------------------------------
function Copperwise:CreateLocale(tables)
    local enUS = tables.enUS or {}
    return setmetatable({}, { __index = function(_, key) return enUS[key] or key end })
end

-------------------------------------------------------------------------------
-- Initialization: ADDON_LOADED
-------------------------------------------------------------------------------
Copperwise:RegisterEvent("ADDON_LOADED", function(event, loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end

    -- SavedVariables initialisation with defaults
    Copperwise:CallModules("OnInitialize")
    -- Feature modules init (loaded after core via .toc order)
    Copperwise:CallFeatures("OnInitialize")

    -- Welcome message (deferred to avoid taint)
    C_Timer.After(0, function()
        print(L["ADDON_LOADED"])
    end)

    -- This event is no longer needed
    Copperwise:UnregisterEvent("ADDON_LOADED")
end)

-- PLAYER_LOGIN: modules can now access game data
Copperwise:RegisterEvent("PLAYER_LOGIN", function()
    Copperwise:CallModules("OnEnable")
    Copperwise:CallFeatures("OnEnable")
    Copperwise:UnregisterEvent("PLAYER_LOGIN")
end)

-------------------------------------------------------------------------------
-- Feature Module System (for addon features like Auction, History, etc.)
-------------------------------------------------------------------------------
local features = {}
local featureSlashCommands = {}
local headerButtons = {}

--- Registers a feature module (features, not infrastructure)
--- @param name string Unique feature name (e.g. "auction")
--- @param module table Module table with OnInitialize/OnEnable callbacks
function Copperwise:RegisterFeature(name, module)
    features[name] = module
    module.name = name
    return module
end

--- Returns a feature module by name
function Copperwise:GetFeature(name)
    return features[name]
end

--- Calls a method on every feature module
function Copperwise:CallFeatures(method, ...)
    for _, mod in pairs(features) do
        if type(mod[method]) == "function" then
            mod[method](mod, ...)
        end
    end
end

--- Registers a /cw <subcommand> for a feature module
function Copperwise:RegisterSlashCommand(subcommand, callback)
    featureSlashCommands[subcommand:lower()] = callback
end

--- Registers a button in the main window's header bar
--- @param name string Button ID
--- @param label string|function Button text, or a function returning it
--- @param callback function OnClick handler
function Copperwise:RegisterHeaderButton(name, label, callback)
    headerButtons[#headerButtons + 1] = { name = name, label = label, callback = callback }
end

--- Unregisters a header button by name.
--- @return boolean true if the button was found and removed
function Copperwise:UnregisterHeaderButton(name)
    for i, btn in ipairs(headerButtons) do
        if btn.name == name then
            table.remove(headerButtons, i)
            return true
        end
    end
    return false
end

--- Unregisters a slash subcommand.
function Copperwise:UnregisterSlashCommand(subcommand)
    if subcommand then
        featureSlashCommands[subcommand:lower()] = nil
    end
end

--- Unregisters a feature module and removes its header buttons and slash commands.
--- Used to switch a feature off at runtime (without a UI reload).
function Copperwise:UnregisterFeature(name)
    if not features[name] then return false end
    features[name] = nil
    -- Header buttons are often registered under the same key as the feature
    self:UnregisterHeaderButton(name)
    return true
end

--- Returns the registered header buttons (for UI/MainFrame)
function Copperwise:GetHeaderButtons()
    return headerButtons
end

-------------------------------------------------------------------------------
-- Debug mode flag (declared BEFORE slash handler so `not debugMode` resolves
-- to this local, not a stray global. Setter/printers live further down.)
-------------------------------------------------------------------------------
local debugMode = false

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
SLASH_COPPERWISE1 = "/cw"
SLASH_COPPERWISE2 = "/copperwise"

--- Finds a feature slash callback for cmd. Two forms are supported:
---   1. Exact match         ("calc" → featureSlashCommands["calc"])
---   2. Prefix and a space  ("goal 1000" → featureSlashCommands["goal"], arg = "1000")
--- Returns (callback, arg_string_or_nil), or nil.
local function findFeatureSlash(cmd)
    if featureSlashCommands[cmd] then
        return featureSlashCommands[cmd], nil
    end
    -- Search registered keys for "key " prefix; longest match wins.
    local matchedKey, matchedFn
    for key, fn in pairs(featureSlashCommands) do
        if cmd:sub(1, #key + 1) == (key .. " ") then
            if not matchedKey or #key > #matchedKey then
                matchedKey, matchedFn = key, fn
            end
        end
    end
    if matchedFn then
        return matchedFn, strtrim(cmd:sub(#matchedKey + 1))
    end
    return nil, nil
end

SlashCmdList["COPPERWISE"] = function(msg)
    local cmd = strtrim(msg):lower()

    if cmd == "reset" then
        local Data = Copperwise:GetModule("Data")
        if Data then
            Data:ResetCharacterData()
            print("|cffb87333Copperwise:|r " .. L["RESET_CONFIRM"])
        end
    elseif cmd == "debug" then
        Copperwise:SetDebug(not debugMode)
    elseif cmd == "dump" then
        local Data = Copperwise:GetModule("Data")
        if Data then
            Copperwise:DumpTable("Daily", Data:GetDailySummary())
            Copperwise:DumpTable("Monthly", Data:GetMonthlySummary())
            Copperwise:DumpTable("Settings", Data:GetSettings())
            print("|cff888888[GL:Dump]|r Entries: " .. #Data:GetRecentEntries(999))
        end
    elseif cmd == "settings" or cmd == "config" then
        local UI = Copperwise:GetModule("UI")
        if UI then UI:ToggleSettingsFrame() end
    elseif cmd == "help" then
        print("|cffb87333Copperwise:|r " .. L["SLASH_HELP"])
    else
        local fn, arg = findFeatureSlash(cmd)
        if fn then
            -- Built-in slash commands take precedence over feature dispatch
            -- so "reset"/"help" etc. cannot be hijacked by a feature.
            fn(arg)
        else
            -- Default: toggle main window
            local UI = Copperwise:GetModule("UI")
            if UI then
                UI:ToggleMainFrame()
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Debug System (debugMode local is declared above the slash handler)
-------------------------------------------------------------------------------

--- Turns debug mode on or off
function Copperwise:SetDebug(enabled)
    debugMode = enabled
    print("|cffb87333Copperwise:|r debug " .. (enabled and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
end

--- Prints a debug message to chat (only when debug is on)
--- @param module string Module name
--- @param ... any Values to join
function Copperwise:Debug(module, ...)
    if not debugMode then return end

    local args = {...}
    local parts = {}
    for i = 1, #args do
        parts[i] = tostring(args[i])
    end

    print(("|cff888888[GL:%s]|r %s"):format(module, table.concat(parts, " ")))
end

--- Dumps a table to chat (debug mode)
--- @param label string Label
--- @param tbl table Table to print
function Copperwise:DumpTable(label, tbl)
    if not debugMode then return end

    print("|cff888888[GL:Dump]|r " .. label .. ":")
    if type(tbl) ~= "table" then
        print("  " .. tostring(tbl))
        return
    end
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            print(("  %s = {%d items}"):format(tostring(k), #v > 0 and #v or 0))
        else
            print(("  %s = %s"):format(tostring(k), tostring(v)))
        end
    end
end

-------------------------------------------------------------------------------
-- Utility: expose L on the namespace for convenience
-------------------------------------------------------------------------------
Copperwise.L = L
