# Copperwise

A World of Warcraft addon that tracks every copper in and out: vendors, the Auction House, mail, loot, quests, repairs, trades and your warband bank. Daily and monthly summaries, a chart, a savings goal, and every character on your account.

![Version](https://img.shields.io/badge/version-1.0.1-b87333)
![Interface](https://img.shields.io/badge/interface-120100-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Automatic tracking** from vendors, repairs, the Auction House, mail, quests, loot, trades, guild bank and warband bank
- **Item names for sales**: what you sold to vendors (including Sell Junk) and on the Auction House, with quantities
- **Warband bank aware**: deposits and withdrawals are transfers, not income or spending, and the bank balance counts towards your goal
- **Auction House tracker** with sales, purchases, listing deposits and the AH cut
- **Daily, monthly and session summaries**, with an interactive 7-day / 30-day / all-time chart
- **Transaction history** with pagination and filters by source, type and minimum amount
- **Source breakdown** for today, week, month or all time
- **Savings goal** with a progress bar and ETA
- **Multi-character overview**, built-in calculator and CSV export
- **Minimap button** (LibDBIcon) with today's and this month's totals
- **Modular**: delete any `Modules/<Name>/` folder to remove that feature

## Installation

Copy the `Copperwise` folder into your AddOns directory:

```
World of Warcraft/_retail_/Interface/AddOns/Copperwise/
```

Restart the client (a new addon folder isn't picked up by `/reload`).

### Coming from GoldLedger

Keep GoldLedger enabled for your first login with Copperwise. Copperwise copies your GoldLedger history, warband bank balance and goal, prints how much it imported, and from then on you can disable or remove GoldLedger. The import runs once, only while Copperwise has no data of its own.

## Usage

| Command | Effect |
| --- | --- |
| `/cw` | Toggle the main window |
| `/cw auction` or `/cwa` | Auction history |
| `/cw history` | Transaction history |
| `/cw chars` | Characters overview |
| `/cw calc` | Calculator |
| `/cw export` | CSV export |
| `/cw goal` | Set a savings goal |
| `/cw reset` | Reset the current character's data |
| `/cw help` | List all commands |

Your data is saved in `WTF/Account/<account>/SavedVariables/Copperwise.lua` when you log out or `/reload`.

## Development

Requires [LuaJIT](https://luajit.org/), which implements Lua 5.1 like the WoW client.

```bash
luajit tests/harness.lua .
luajit tests/minimap.lua .
luajit tests/globals.lua .
```

`tests/harness.lua` loads the addon's core files against a minimal WoW API stub and drives gold changes through `PLAYER_MONEY`: bank transfers, vendor sales, the GoldLedger import and more. `tests/minimap.lua` loads the embedded libraries and the minimap module. `tests/globals.lua` fails if the addon assigns a global it doesn't own, which would taint Blizzard code. CI runs all three, plus a syntax check of every Lua file and a check that every file in `Copperwise.toc` exists.

## Releasing

1. Bump `## Version` in `Copperwise.toc` and add a section to `CHANGELOG.md`.
2. Commit, then tag and push: `git tag -a v1.0.1 -m "Copperwise 1.0.1"` and `git push origin main v1.0.1`.

The Release workflow runs the tests, checks the tag matches the `.toc` version, and uploads the package to CurseForge and GitHub Releases. It needs a `CF_API_KEY` repository secret containing a CurseForge API token.

## Credits

Copperwise is based on [GoldLedger](https://www.curseforge.com/wow/addons/goldledger) by **tum24**, released under the MIT License. The first commit in this repository is the unmodified GoldLedger 2.4.4; see [CHANGELOG.md](CHANGELOG.md) for everything since.

## License

MIT. © NeonRat85; original GoldLedger © tum24. See [LICENSE](LICENSE).

Embedded libraries in `Libs/` keep their own licences: LibStub and LibDataBroker-1.1 are public domain; CallbackHandler-1.0 and LibDBIcon-1.0 use the Ace3 BSD licence. See [Libs/README.md](Libs/README.md).
