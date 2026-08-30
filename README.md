# GL.iNet Bandwidth Script

Per-VLAN and per-SSID bandwidth priority for **GL.iNet Flint 2**, **GL.iNet Flint 3**, **GL.iNet Flint 4 / GL-BE14000**, **GL.iNet Slate 7**, **GL.iNet Slate 7 Pro**, **GL.iNet Beryl 7**, and **GL.iNet Flint 3e / GL-BE6500** using **HTB + CAKE** on OpenWrt.

Supports both **QoS** (per-VLAN/SSID priority) and **SQM** (Smart Queue Management with CAKE) modes.

---

## Documentation

- [Supported Models](https://github.com/wickedyoda/Glinet-Bandwidth-script/wiki/Supported-Models)
- [Setup Wizard](https://github.com/wickedyoda/Glinet-Bandwidth-script/wiki/Setup-Wizard)
- [QoS vs SQM](https://github.com/wickedyoda/Glinet-Bandwidth-script/wiki/QoS-vs-SQM)
- [Persistence](https://github.com/wickedyoda/Glinet-Bandwidth-script/wiki/Persistence)
- [Configuration](https://github.com/wickedyoda/Glinet-Bandwidth-script/wiki/Configuration)
- [Troubleshooting](https://github.com/wickedyoda/Glinet-Bandwidth-script/wiki/Troubleshooting)

---

## Supported Models & Firmware

| Model | Firmware | OpenWrt | Kernel | Notes |
|-------|----------|---------|--------|-------|
| **GL.iNet Flint 3** | 4.9.0 | 23.05-SNAPSHOT | 5.4.213 | `tc-full`, supports `u32` filters |
| **GL.iNet Flint 2** | 4.9.1 | 21.02-SNAPSHOT | 5.4.238 | `tc-tiny`, **no `u32` filters** |
| **GL.iNet Flint 4 / GL-BE14000** | 4.9.1 | 21.02-SNAPSHOT | 5.4.281 | `tc-tiny`, **no `u32` filters** |
| **GL.iNet Slate 7** | 4.9.0 | 23.05-SNAPSHOT | 5.4.213 | `tc-full`, supports `u32` filters |
| **GL.iNet Slate 7 Pro / GL-BE10000** | 4.8.4 | 21.02-SNAPSHOT | 5.4.281 | `tc-tiny`, **no `u32` filters** |
| **GL.iNet Beryl 7 / GL-MT3600BE** | 4.9.0 | 21.02-SNAPSHOT | 5.4.281 | `tc-tiny`, **no `u32` filters** |
| **GL.iNet Flint 3e / GL-BE6500** | 4.9.0 | 23.05-SNAPSHOT | 5.4.213 | `tc-full`, supports `u32` filters |

> The script auto-detects your model. If detection fails, it warns you and asks for confirmation before continuing with Flint 2-safe defaults.
>
> Note: When a model is retested after a firmware upgrade, the new firmware version is added alongside the existing entries rather than replacing them.

---

## Quick Start

```sh
# One-liner install
curl -fsSL https://raw.githubusercontent.com/wickedyoda/Glinet-Bandwidth-script/main/install.sh | sh

# Run interactive setup
/usr/local/sbin/glinet-vlan-qos-setup.sh
```

The setup wizard will:
1. Ask you to choose **QoS** or **SQM** mode
2. Let you select your model or auto-detect
3. Let you choose persistence mode
4. Show detected VLANs/SSIDs and let you assign priority order
5. Apply the configuration and verify it's working

---

## How It Works

1. **Auto-detects** Flint 2 / Flint 3 / Flint 4 / Slate 7 / Slate 7 Pro / Beryl 7 / Flint 3e at runtime
2. **HTB root qdisc** on each bridge/interface
3. **Priority classes**:
   - Class 10 (`prio 1`): LAN + Tailscale — highest priority
   - Class 20 (`prio 2`): IoT — medium priority
   - Class 30 (`prio 3`): Guest — lowest priority
4. **CAKE leaf qdisc** for smart queue management
5. **nft marks** by ingress interface for traffic classification
6. **Persistence** via `/etc/gl-switch.d/` + `/etc/rc.local`

---

## Files

| File | Purpose |
|------|---------|
| `glinet-vlan-qos.sh` | Main QoS engine |
| `glinet-vlan-qos-setup.sh` | Interactive setup wizard |
| `install.sh` | One-liner installer |
| `README.md` | This documentation |

---

## Usage

```sh
# Run interactive setup
glinet-vlan-qos-setup.sh
```

---

## Modes

### QoS Mode
Per-VLAN/SSID priority with HTB + CAKE.
- Prioritizes LAN, IoT, Guest, and Tailscale by bridge/interface
- Best for multi-VLAN homes and office networks

### SQM Mode
Smart Queue Management with CAKE.
- Simple bandwidth limit per WAN interface
- Best for bufferbloat reduction on single WAN

---

## Priority Order

| Priority | Bridge/Interface | Traffic Type |
|----------|------------------|--------------|
| **Top** | `br-lan` + `tailscale0` | LAN + Tailscale mesh |
| **Medium** | `br-iot` | IoT devices |
| **Low** | `br-guest` | Guest network |

---

## Persistence Options

### Option 1: Persistent through firmware upgrades (`PERSISTENT=1`, default)
- Installs hook in `/etc/gl-switch.d/vlan-qos.sh` — runs after network switches
- Appends start command to `/etc/rc.local` — runs on boot
- Survives: firmware upgrades, UI config changes, network restarts
- Does **not** survive: factory reset (expected)

### Option 2: Manual/scripted only (`PERSISTENT=0`)
- No auto-start hooks installed
- Survives UI config changes but not reboots/firmware upgrades
- Use for testing or temporary QoS

---

## Configuration

Edit `/etc/gl-qos-vlan.conf` on the router:

```bash
# Bandwidth limits (kbit/s)
QOS_LAN_BW_UP=200000          # 200 Mbps
QOS_LAN_BW_DOWN=500000        # 500 Mbps
QOS_IOT_BW_UP=50000           # 50 Mbps
QOS_IOT_BW_DOWN=100000        # 100 Mbps
QOS_GUEST_BW_UP=20000         # 20 Mbps
QOS_GUEST_BW_DOWN=50000       # 50 Mbps
QOS_TAILSCALE_BW_UP=50000     # 50 Mbps
QOS_TAILSCALE_BW_DOWN=100000  # 100 Mbps

# Enable/disable CAKE leaf qdisc
CAKE_ENABLE=1

# Persistence mode
PERSISTENT=1
```

---

## Default Bandwidth by Model

| Model | LAN | IoT | Guest | Tailscale |
|-------|-----|-----|-------|-----------|
| **Flint 3** | 200/500 Mbps | 50/100 Mbps | 20/50 Mbps | 50/100 Mbps |
| **Flint 2** | 100/300 Mbps | 30/80 Mbps | 10/30 Mbps | 30/80 Mbps |
| **Flint 4 / GL-BE14000** | 100/300 Mbps | 30/80 Mbps | 10/30 Mbps | 30/80 Mbps |

---

## Verification

```sh
# Check QoS status
glinet-vlan-qos.sh status

# Verify detected model
glinet-vlan-qos.sh detect

# Verify HTB classes
tc class show dev br-lan
tc class show dev br-iot
tc class show dev br-guest

# Verify nft marks
nft list table inet gl-qos
```

---

## Uninstall

```sh
glinet-vlan-qos.sh uninstall
```

This removes:
- `/etc/gl-switch.d/vlan-qos.sh`
- `/usr/local/sbin/glinet-vlan-qos.sh`
- All HTB qdiscs and nft marks

---

## Files Modified

| File | Purpose |
|------|---------|
| `/usr/local/sbin/glinet-vlan-qos.sh` | Main script |
| `/etc/gl-switch.d/vlan-qos.sh` | Network restart hook |
| `/etc/rc.local` | Boot persistence |
| `/etc/gl-qos-vlan.conf` | Custom config (optional) |

---

## Requirements

- GL.iNet Flint 2, Flint 3, Flint 4, Slate 7, Slate 7 Pro, Beryl 7, or Flint 3e
- OpenWrt 21.02+
- Packages: `tc-full` or `tc-tiny`, `kmod-sched-cake`, `sqm-scripts`
- Root SSH access

---

## Troubleshooting

**Model detection fails:**
```sh
# Check board.json
cat /etc/board.json | grep model

# Manually set model
export QOS_MODEL=flint2
glinet-vlan-qos.sh start
```

**QoS not applying on Flint 2/Flint 4:**
```sh
# tc-tiny does not support u32 filters; this is expected
tc filter show dev br-lan

# Check HTB classes are created
tc class show dev br-lan
```

**Persistence not working:**
```sh
# Verify hooks are executable
ls -la /etc/gl-switch.d/vlan-qos.sh
ls -la /usr/local/sbin/glinet-vlan-qos.sh

# Test manually
/etc/gl-switch.d/vlan-qos.sh
```

---

## Disclaimer

> **Use at your own risk.** While we have tested this script on the models and firmware versions listed above, you are solely responsible for any changes made to your router. We are not liable for damages, data loss, or bricked devices resulting from the use of this script.
>
> By proceeding, you agree that you understand the risks and accept full responsibility for the outcome.
>
> Full disclaimer: [Privacy Policy, Terms of Use, Disclaimer and Limitation of Liability](https://www.wickedyoda.com/privacy-policy-terms-of-use-disclaimer-and-limitation-of-liability/)
>
> If you encounter issues, please [open an issue ticket](https://github.com/wickedyoda/Glinet-Bandwidth-script/issues).

---

## License

GPLv3 — see `LICENSE` for details.