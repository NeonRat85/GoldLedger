--[[
    Copperwise / AuctionTracker: Locale.lua
    Self-contained localization for this module.
    Does not touch ns.L (core locale).
]]

local ADDON_NAME, ns = ...
ns.AuctionTracker = ns.AuctionTracker or {}

local enUS = {
    AUCTION_BUTTON          = "Auction",
    AUCTION_TITLE           = "Copperwise — Auction History",

    -- Filter labels
    AUCTION_PERIOD          = "Period:",
    AUCTION_TYPE            = "Type:",
    AUCTION_SEARCH          = "Search:",

    -- Period options
    AUCTION_PERIOD_TODAY    = "Today",
    AUCTION_PERIOD_WEEK     = "Week",
    AUCTION_PERIOD_MONTH    = "Month",
    AUCTION_PERIOD_ALL      = "All",

    -- Type options
    AUCTION_TYPE_ALL        = "All",
    AUCTION_TYPE_SALE       = "Sale",
    AUCTION_TYPE_PURCHASE   = "Purchase",
    AUCTION_TYPE_CUT        = "AH Cut",
    AUCTION_TYPE_DEPOSIT    = "Deposit",

    -- Columns
    AUCTION_COL_TIME        = "Time",
    AUCTION_COL_TYPE        = "Type",
    AUCTION_COL_ITEM        = "Item",
    AUCTION_COL_QTY         = "Qty",
    AUCTION_COL_PRICE       = "Price",
    AUCTION_COL_TOTAL       = "Total",

    -- Status bar
    AUCTION_STATUS_RECORDS  = "Records: %d",
    AUCTION_STATUS_INCOME   = "Income: %s",
    AUCTION_STATUS_EXPENSE  = "Expense: %s",
    AUCTION_STATUS_NET      = "Net: %s",

    -- Misc
    AUCTION_NO_RESULTS      = "No auction transactions match filters.",
    AUCTION_UNKNOWN_ITEM    = "?",
    AUCTION_PAGE            = "Page %d/%d",
    AUCTION_SHOWING         = "Showing %d-%d of %d",
    AUCTION_PREV            = "< Prev",
    AUCTION_NEXT            = "Next >",
}

-- English only; unknown keys fall back to the key itself
local L = setmetatable({}, { __index = function(_, key) return enUS[key] or key end })

ns.AuctionTracker.L = L
