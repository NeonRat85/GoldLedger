--[[
    Copperwise / Goal: Goal.lua
    Feature module entry point.

    Owns the /cw goal slash command (extracted from Core in the SDK cleanup):
        /cw goal           — print usage hint
        /cw goal <N>       — set goal to N gold (must be > 0)
        /cw goal clear     — clear current goal
        /cw goal reset     — alias for clear
]]

local ADDON_NAME, ns = ...
ns.Goal = ns.Goal or {}

local Copperwise = ns.Copperwise
local L = ns.L  -- core L (for shared strings like GOAL_USAGE)

local Module = {}
ns.Goal.Module = Module

if Copperwise and Copperwise.RegisterFeature then
    Copperwise:RegisterFeature("goal", Module)
end

local function handleGoalSlash(arg)
    arg = arg or ""
    local Data = Copperwise and Copperwise:GetModule("Data")
    if not Data then return end

    if arg == "" then
        print("|cffb87333Copperwise:|r " .. L["GOAL_USAGE"])
    elseif arg == "clear" or arg == "reset" then
        Data:ClearGoal()
        print("|cffb87333Copperwise:|r " .. L["GOAL_CLEARED"])
    else
        local n = tonumber(arg)
        if n and n > 0 then
            Data:SetGoal(n * 10000)
            print("|cffb87333Copperwise:|r " .. L["GOAL_SET"]:format(n .. L["GOLD_ABBR"]))
        else
            print("|cffb87333Copperwise:|r " .. L["GOAL_USAGE"])
        end
    end
end

function Module:OnInitialize() end

function Module:OnEnable()
    if Copperwise.RegisterSlashCommand then
        Copperwise:RegisterSlashCommand("goal", handleGoalSlash)
    end
end
