# Supported Models

## Table

| Model | Hardware ID | Firmware | OpenWrt | Kernel | tc | WAN Egress |
|-------|-------------|----------|---------|--------|----|------------|
| **Flint 3** | GL-BE9300 | 4.9.0 | 23.05-SNAPSHOT | 5.4.213 | tc-full | ✅ |
| **Flint 2** | GL-MT6000 | 4.9.1 | 21.02-SNAPSHOT | 5.4.238 | tc-tiny | ✅ |
| **Flint 4** | GL-BE14000 | 4.9.1 | 21.02-SNAPSHOT | 5.4.281 | tc-tiny | ✅ |
| **Slate 7** | GL-BE3600 | 4.9.0 | 23.05-SNAPSHOT | 5.4.213 | tc-full | ✅ |
| **Slate 7 Pro** | GL-BE10000 | 4.8.4 | 21.02-SNAPSHOT | 5.4.281 | tc-tiny | ✅ |
| **Beryl 7** | GL-MT3600BE | 4.9.0 | 21.02-SNAPSHOT | 5.4.281 | tc-tiny | ✅ |
| **Flint 3e** | GL-BE6500 | 4.9.0 | 23.05-SNAPSHOT | 5.4.213 | tc-full | ✅ |

> **WAN Egress**: All models support WAN-rooted HTB. tc-tiny models skip u32 filters.

## How We Test

- **Flint 3 (johns-router)**: Live production device, 9 SSIDs, 37+ clients
- **Flint 2 (wickedyoda-mother)**: Production test device
- **Slate 7/7 Pro (slate-7-travel/slatemybrain)**: Live production devices
- **Beryl 7**: Inspected read-only
- **Flint 3e (gigi-router)**: Inspected read-only
- **Flint 4 (wickedyoda-home)**: Inspected read-only per "NO CHANGES" instruction

## Firmware Upgrade Policy

When a model is retested after a firmware upgrade, the new firmware version is **added alongside existing entries** rather than replacing them. This documents compatibility across versions.

## Notes

- All models tested with `tc-full` or `tc-tiny` as appropriate
- WAN-rooted architecture verified on all models
- Auto-detection uses `/etc/board.json` pattern matching
- Unknown models fall back to Flint 2 defaults with warning