# Embedded libraries

Unmodified copies of the libraries Copperwise uses for its minimap button. Each is
loaded through LibStub, so when several addons embed the same library the newest
copy wins.

| Library | Version | Licence | Source |
| --- | --- | --- | --- |
| LibStub | 2 | Public domain | https://www.curseforge.com/wow/addons/libstub |
| CallbackHandler-1.0 | 8 | Ace3 BSD, see [LICENSE-Ace3.txt](LICENSE-Ace3.txt) | https://www.curseforge.com/wow/addons/callbackhandler |
| LibDataBroker-1.1 | 4 | Public domain | https://github.com/tekkub/libdatabroker-1-1 |
| LibDBIcon-1.0 | 56 | Ace3-style BSD, see [LICENSE-Ace3.txt](LICENSE-Ace3.txt) | https://www.curseforge.com/wow/addons/libdbicon-1-0 |

To update a library, replace its file with the newer release; no Copperwise code changes are needed unless its API changes.
