# Supported Models

This script supports the following GL.iNet models, tested against real hardware where noted.

| Model | Firmware | OpenWrt | Kernel | TC | Status |
|-------|----------|---------|--------|----|--------|
| GL.iNet Flint 3 | 4.9.0 | 23.05-SNAPSHOT | 5.4.213 | tc-full | Tested on johns-router |
| GL.iNet Flint 2 | 4.9.1 | 21.02-SNAPSHOT | 5.4.238 | tc-tiny | Tested on wickedyoda-mother |
| GL.iNet Flint 4 / GL-BE14000 | 4.9.1 | 21.02-SNAPSHOT | 5.4.281 | tc-tiny | Read-only inspected |
| GL.iNet Slate 7 | 4.9.0 | 23.05-SNAPSHOT | 5.4.213 | tc-full | Tested on slate-7-travel |
| GL.iNet Slate 7 Pro / GL-BE10000 | 4.8.4 | 21.02-SNAPSHOT | 5.4.281 | tc-tiny | Tested on slatemybrain |
| GL.iNet Beryl 7 / GL-MT3600BE | 4.9.0 | 21.02-SNAPSHOT | 5.4.281 | tc-tiny | Read-only inspected |
| GL.iNet Flint 3e / GL-BE6500 | 4.9.0 | 23.05-SNAPSHOT | 5.4.213 | tc-full | Read-only inspected |

## How model detection works

The setup wizard can auto-detect your model from `/etc/board.json`. If detection fails, it warns you and asks for confirmation before continuing with Flint 2-safe defaults.

## Why two code paths?

The script has two main code paths based on the `tc` variant available on the router:

- **Flint 3-class** — uses `tc-full`, supports `u32` filters for more granular traffic classification.
- **Flint 2-class** — uses `tc-tiny`, skips `u32` filters and uses simpler HTB + nft marking.

This means even newer-looking models may follow the Flint 2 path if they run `tc-tiny`.

## Bridge layout notes

Different models expose different bridges out of the box:

- **Flint 3 / Flint 3e / Slate 7** — typically `br-lan`, `br-iot`, `br-guest`, `tailscale0`
- **Flint 2 / Flint 4 / Slate 7 Pro / Beryl 7** — typically `br-lan`, `br-guest`, `tailscale0`

The script checks for bridge existence before applying QoS, so missing interfaces are handled safely.
