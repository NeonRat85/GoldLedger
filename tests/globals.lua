-- Fails if Copperwise's own code assigns a global it doesn't own.
-- Assigning a Blizzard global (even to its current value) taints it, and any
-- secure code that reads it afterwards runs tainted: e.g. `SlashCmdList =
-- SlashCmdList or {}` made every slash command blame Copperwise for
-- ADDON_ACTION_FORBIDDEN. Uses LuaJIT bytecode listings, so it sees real
-- global stores (GSET) rather than guessing from source text.
-- Usage: luajit tests/globals.lua [addon directory]

local dir = ... or "."

-- Globals Copperwise may set: its SavedVariables, its own names and slash aliases
local ALLOWED = {
    "^CopperwiseDB$",
    "^Copperwise$",
    "^SLASH_COPPERWISE%w*%d$",
}

local function allowed(name)
    for _, pattern in ipairs(ALLOWED) do
        if name:match(pattern) then return true end
    end
    return false
end

-- Lua files the client loads, from the .toc (embedded libraries excluded)
local files = {}
for line in io.lines(dir .. "/Copperwise.toc") do
    line = line:gsub("\r$", "")
    if line ~= "" and not line:match("^#") and not line:match("^Libs[\\/]") and line:match("%.lua$") then
        files[#files + 1] = (line:gsub("\\", "/"))
    end
end

local failures = 0
for _, file in ipairs(files) do
    local path = dir .. "/" .. file
    local listing = assert(io.popen('luajit -bl "' .. path .. '"')):read("*a")
    for name in listing:gmatch('GSET[^\n]-"([^"\n]+)"') do
        if not allowed(name) then
            failures = failures + 1
            print(("FAIL %s assigns global %s"):format(file, name))
        end
    end
    -- `_G.Name = ...` compiles to a table store on _G, not GSET
    local source = assert(io.open(path)):read("*a")
    for name in source:gmatch("_G%.([%a_][%w_]*)%s*=[^=]") do
        if not allowed(name) then
            failures = failures + 1
            print(("FAIL %s assigns _G.%s"):format(file, name))
        end
    end
end

print(failures == 0 and ("globals ok (" .. #files .. " files)") or (failures .. " disallowed global assignment(s)"))
os.exit(failures == 0 and 0 or 1)
