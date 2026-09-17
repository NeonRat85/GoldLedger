# Changelog

All notable changes to this fork are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
