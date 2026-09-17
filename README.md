# GoldLedger (fork)

A World of Warcraft addon that tracks your gold income and expenses, with daily and monthly summaries, charts, a savings goal and multi-character support.

![Version](https://img.shields.io/badge/version-2.5.0-blue)
![Interface](https://img.shields.io/badge/interface-120100-orange)
![License](https://img.shields.io/badge/license-MIT-green)

This is a fork of [GoldLedger](https://www.curseforge.com/wow/addons/goldledger) by **tum24**, released under the MIT License. The first commit in this repository is the unmodified 2.4.4 release; everything after it is changes made in this fork. See [CHANGELOG.md](CHANGELOG.md).

## What this fork changes

- **Warband bank deposits and withdrawals are transfers, not expenses or income.** They show in the transaction list tagged *Bank* but don't affect totals, charts or session stats.
- **Warband bank balance** is shown under *On Hand* and in the minimap tooltip, and counts towards your goal.
- **Minimap button uses LibDBIcon**, so it behaves like other addons' buttons and works with minimap button managers.
- **Guild bank** gold is labelled *Guild* instead of *Other*. It still counts as income/expense, because gold given to the guild is no longer yours.

## Features

- **Automatic tracking** from vendors, repairs, the auction house, mail, quests, loot, trades and banks
- **Auction House tracker** with sales, purchases, deposits and commission
- **Daily, monthly and session summaries**, with an interactive 7-day / 30-day / all-time chart
- **Transaction history** with pagination and filters by source, type and minimum amount
- **Source breakdown** for today, week, month or all time
- **Savings goal** with a progress bar and ETA
- **Multi-character overview**, built-in calculator and CSV export
- **English and Russian**, switchable in game
- **Modular**: delete any `Modules/<Name>/` folder to remove that feature

## Installation

Copy the `GoldLedger` folder into your AddOns directory:

```
World of Warcraft/_retail_/Interface/AddOns/GoldLedger/
```

Restart the client or `/reload`. If you previously installed GoldLedger through the CurseForge app, remove it there first so an update doesn't overwrite this fork.

## Usage

| Command | Effect |
| --- | --- |
| `/gl` | Toggle the main window |
| `/gl auction` or `/gla` | Auction history |
| `/gl history` | Transaction history |
| `/gl chars` | Characters overview |
| `/gl calc` | Calculator |
| `/gl export` | CSV export |
| `/gl goal` | Set a savings goal |
| `/gl reset` | Reset the current character's data |
| `/gl help` | List all commands |

## Development

Requires [LuaJIT](https://luajit.org/), which implements Lua 5.1 like the WoW client.

```bash
luajit tests/harness.lua .
luajit tests/minimap.lua .
```

`tests/harness.lua` loads the addon's real core files against a minimal WoW API stub and drives gold changes through `PLAYER_MONEY`. `tests/minimap.lua` loads the embedded libraries and the minimap module, and checks registration, the tooltip, visibility and settings migration. CI runs both, along with a syntax check of every Lua file and a check that every file listed in `GoldLedger.toc` exists.

## License

MIT. Original work © tum24; modifications © NeonRat85. See [LICENSE](LICENSE).

Embedded libraries in `Libs/` keep their own licences: LibStub and LibDataBroker-1.1 are public domain; CallbackHandler-1.0 and LibDBIcon-1.0 use the Ace3 BSD licence. See [Libs/README.md](Libs/README.md).
