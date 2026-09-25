# Server smoke test

Boots the real Config + Creatures + GameServer inside a small Roblox stand-in (`mock.luau`), joins players and pushes
Robux receipts through `ProcessReceipt` (donation, price mismatch, `!donor` online/offline credit + rejoin).

    python3 tests/build.py && luau tests/all.luau

Needs the standalone `luau` binary (github.com/luau-lang/luau releases). Any "ERR" line or a missing
"PurchaseGranted" means something is broken.
