local ADDON_NAME, ns = ...
ns.Export = ns.Export or {}

local enUS = {
    EXPORT_BUTTON = "Export",
    EXPORT_TITLE  = "Export Data (CSV)",
    EXPORT_HINT   = "Ctrl+A, then Ctrl+C to copy",
}

-- English only; unknown keys fall back to the key itself
local L = setmetatable({}, { __index = function(_, key) return enUS[key] or key end })

ns.Export.L = L
