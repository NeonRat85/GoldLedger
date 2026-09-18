# Changelog

All notable changes to this fork are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **Protected slash commands blocked and blamed on GoldLedger.** The Auction
  module ran `SlashCmdList = SlashCmdList or {}`, which reassigns Blizzard's
  global to itself and taints it. Every slash command then ran tainted, so
  protected ones such as `/pvp` failed with `ADDON_ACTION_FORBIDDEN` naming
  GoldLedger. The module now only adds its own key. Present since the
  original 2.4.4.

### Added

- **Total line in the minimap tooltip** for Today and This Month: income minus
  expense, green when positive and red when negative.
- `tests/globals.lua`, run in CI, fails if GoldLedger's code assigns any
  global it doesn't own.

### Added

- **Item names for vendor sales.** Vendor income is matched to the merchant's
  buyback list by exact sale price, so entries record what was sold and how
  many, whether sold by right-click, drag, Sell Junk or a vendoring addon.
  Several items sold in one go (such as Sell Junk) are recorded together.
  Entries gain `itemName`, `quantity`, `vendorType = "sale"` and, for multiple
  items, `items`. Sales that can't be matched within 5 seconds stay unnamed.
- Item names (auction and vendor) are shown in the main window and History
  transaction lists.
- `Data:AddEntry` returns the stored entry, and an `ENTRIES_UPDATED` event
  refreshes the UI when an entry gains details after it was logged.

### Changed

- **Minimap button now uses LibDBIcon-1.0.** The hand-built button is replaced by
  a LibDataBroker-1.1 launcher drawn by LibDBIcon, the library most addons use for
  minimap buttons. It behaves like the others: consistent hover and click, drag to
  move, round and square minimap shapes, and support for minimap button managers
  and broker displays. LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and
  LibDBIcon-1.0 are embedded under `Libs/` (see `Libs/README.md` for versions and
  licences).
- Button position and visibility are stored in `GoldLedgerDB.settings.minimap`
  (LibDBIcon's `{ minimapPos, hide }`). Existing `minimapPos`, `showMinimap` and
  `minimapHidden` values are migrated on first load.

### Fixed

- **Minimap button tooltip and clicks not working reliably.** The old button set
  its strata and level without fixing them, so re-layering of the toplevel
  minimap cluster could drop it beneath the minimap, which then took the mouse.
  Its border was also larger than, and offset from, the clickable area.
- The minimap setting could disagree with what was shown after a reload, because
  the Settings checkbox and the button saved visibility under different keys.

## [2.5.0]

### Fixed

- **Warband bank deposits were logged as "Other" expenses.** Depositing gold
  lowered the character's money, so the tracker recorded it as spending, and
  withdrawals as income. Calls to `C_Bank.DepositMoney` / `C_Bank.WithdrawMoney`
  for `Enum.BankType.Account` are now hooked and matched to the following
  `PLAYER_MONEY` by exact amount and direction (matches expire after 10 seconds).
  Matched moves are logged as `transfer` entries, which appear in transaction
  lists but are excluded from income/expense totals, charts and session stats.

### Added

- **Warband bank balance** under "On Hand" and in the minimap tooltip, read from
  `C_Bank.FetchDepositedMoney` on `ACCOUNT_MONEY` and when the bank opens, and
  cached account-wide in SavedVariables.
- **Goal progress counts the warband bank**, so depositing no longer sets it back.
- **Bank** and **Guild** sources. Other gold spent at the bank (such as tab
  purchases) is labelled Bank; guild bank deposits and withdrawals are labelled
  Guild and still count as expense/income, since that gold leaves the player.
- Bank and Guild filters in the main window and History, rows in Source Breakdown,
  a "Bank Transfer" type filter in History, and `bank_deposit` / `bank_withdraw`
  types in CSV export. English and Russian strings.
- Test harness (`tests/harness.lua`) and CI running a Lua 5.1 syntax check, the
  harness and a `.toc` reference check.

### Changed

- Removed `X-Curse-Project-ID` from the `.toc`, since this fork is not the
  CurseForge project.

## [2.4.4]

Original release by tum24, imported unmodified from
[CurseForge](https://www.curseforge.com/wow/addons/goldledger).
