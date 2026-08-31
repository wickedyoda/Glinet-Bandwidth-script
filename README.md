# GL.iNet Bandwidth Script

Per-VLAN/SSR and WAN-rooted bandwidth priority for **GL.iNet Flint 2**, **GL.iNet Flint 3**, **GL.iNet Flint 4 / GL-BE14000**, **GL.iNet Slate 7**, **GL.iNet Slate 7 Pro**, **GL.iNet Beryl 7**, and **GL.iNet Flint 3e / GL-BE6500** using **HTB + CAKE** on OpenWrt.

Supports both **QoS** (WAN-rooted per-VLAN/SSID priority) and **SQM** (Smart Queue Management with CAKE) modes.

---

## Documentation

- [Supported Models](https://github.com/wickedyoda/Glinet-Bandwidth-script/wiki/Supported-Models)
- [Setup Wizard](https://github.com/wickedyoda/Glinet-Bandwidth-script/wiki/Setup-Wizard)
- [QoS vs SQM](https://github.com/wickedyoda/Glinet-Bandwidth-script/wiki/QoS-vs-SQM)
- [Persistence](https://github.com/wickedyoda/Glinet-Bandwidth-script/wiki/Persistence)
- [Configuration](https://github.com/wickedyoda/Glinet-Bandwidth-script/wiki/Configuration)
- [Troubleshooting](https://github.com/wickedyoda/Glinet-Bandwidth-script/wiki/Troubleshooting)

---

## Quick Start

```sh
# One-liner install
curl -fsSL https://raw.githubusercontent.com/wickedyoda/Glinet-Bandwidth-script/master/install.sh | sh

# Run interactive setup
/usr/local/sbin/glinet-vlan-qos-setup.sh
```

The setup wizard will:
1. Ask you to choose **QoS** (WAN-rooted HTB) or **SQM** (WAN CAKE diffserv) mode
2. Let you select your model or auto-detect
3. Let you choose persistence mode
4. Set WAN upload/download limits and assign VLAN priority
5. Apply the configuration and verify it's working

---

## How It Works

**NEW WAN-Rooted Architecture:**
1. **Auto-detects** Flint 2 / Flint 3 / Flint 4 / Slate 7 / Slate 7 Pro / Beryl 7 / Flint 3e at runtime
2. **HTB root qdisc** on WAN interface (`eth0`) with total bandwidth cap
3. **Priority classes** with CAKE leaf qdiscs:
   - Class 10 (`prio 1`): LAN + Tailscale — **highest** WAN priority
   - Class 20 (`prio 2`): IoT — medium priority  
   - Class 30 (`prio 3`): Guest — lowest priority
4. **nft fwmark classification** steers traffic to WAN classes
5. **Optional bridge-level shaping** for wired LAN clients
6. **Persistence** via `/etc/gl-switch.d/` + `/etc/rc.local` + `/etc/sysupgrade.conf.d/`

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

# Manual control
glinet-vlan-qos.sh start|stop|restart|status|detect
```

---

## Modes

### QoS Mode (default)
WAN-rooted HTB + CAKE with per-VLAN priority

- Shaped at WAN egress for proper upload arbitration
- HTB classes prioritize LAN > IoT > Guest
- Optional bridge-level shaping for wired traffic

### SQM Mode
Smart Queue Management with CAKE diffserv

- Single WAN CAKE qdisc at measured bandwidth
- Best for bufferbloat reduction on single WAN connection
- Set `WAN_BW_UP/DOWN` in config

---

## Priority Order

| Priority | Bridge/Interface | Traffic Type |
|----------|------------------|--------------|
| **Top** | `br-lan` + `tailscale0` | LAN + Tailscale mesh |
| **Medium** | `br-iot` | IoT devices |
| **Low** | `br-guest` | Guest network |

---

## Configuration

Edit `/etc/gl-qos-vlan.conf` on the router:

```bash
# WAN bandwidth limits (kbit/s)
WAN_BW_UP=100000          # 100 Mbps upload
WAN_BW_DOWN=500000        # 500 Mbps download

# Per-VLAN limits (kbps)
QOS_LAN_BW_UP=200000
QOS_LAN_BW_DOWN=500000
QOS_IOT_BW_UP=100000
QOS_IOT_BW_DOWN=200000
QOS_GUEST_BW_UP=100000
QOS_GUEST_BW_DOWN=200000
QOS_TAILSCALE_BW_UP=200000
QOS_TAILSCALE_BW_DOWN=500000

# Enable CAKE leaf qdisc
CAKE_ENABLE=1

# Persistence mode
PERSISTENT=1
```

---

## Default Bandwidth by Model

| Model | WAN UP | LAN | IoT | Guest | Tailscale |
|-------|--------|-----|-----|-------|-----------|
| Flint 3 | 100/500 Mbps | 200/500 | 100/200 | 100/200 | 200/500 |
| Flint 2 | 100/300 Mbps | 100/300 | 50/100 | 20/50 | 50/100 |
| Flint 4 | 100/300 Mbps | 100/300 | 50/100 | 20/50 | 50/100 |
| Slate 7 | 100/500 Mbps | 200/500 | 100/200 | 100/200 | 200/500 |
| Slate 7 Pro | 100/300 Mbps | 100/300 | 50/100 | 20/50 | 50/100 |
| Beryl 7 | 100/300 Mbps | 100/300 | 50/100 | 20/50 | 50/100 |
| Flint 3e | 100/500 Mbps | 200/500 | 100/200 | 100/200 | 200/500 |

---

## Verification

```sh
# Check QoS status
glinet-vlan-qos.sh status

# Verify detected model
glinet-vlan-qos.sh detect

# Verify WAN qdisc
tc class show dev eth0

# Verify nft marks
nft list table inet gl-qos
```

---

## Persistence Options

### Enable Persistence (`PERSISTENT=1`)
- Installs hook in `/etc/gl-switch.d/vlan-qos.sh` — runs after network changes
- Appends start command to `/etc/rc.local` — runs on boot
- Adds to `/etc/sysupgrade.conf.d/` for firmware upgrade survival
- Survives: firmware upgrades, network restarts
- **Does NOT survive**: factory reset

### Disable Persistence (`PERSISTENT=0`)
- No auto-start hooks installed
- Use for testing or temporary QoS

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

**WAN egress not shaped:**
```sh
# Verify qdisc on WAN interface
tc qdisc show dev eth0

# Check class allocations
tc class show dev eth0
```

**Persistence not surviving upgrades:**
```sh
# Verify sysupgrade protection
cat /etc/sysupgrade.conf.d/glinet-qos.conf
ls -la /lib/upgrade/retain.d/
```

---

## Disclaimer

> **Use at your own risk.** While we have tested this script on the models and firmware versions listed above, you are solely responsible for any changes made to your router. We are not liable for damages, data loss, or bricked devices resulting from the use of this script.
> 
> Full disclaimer: [Privacy Policy, Terms of Use, Disclaimer and Limitation of Liability](https://www.wickedyoda.com/privacy-policy-terms-of-use-disclaimer-and-limitation-of-liability/)
> 
> If you encounter issues, please [open an issue ticket](https://github.com/wickedyoda/Glinet-Bandwidth-script/issues).

---

## License

GPLv3 — see `LICENSE` for details.