# GL.iNet Bandwidth Script

Per-VLAN and per-SSID bandwidth priority for **GL.iNet Flint 2** and **GL.iNet Flint 3** using **HTB + CAKE** on OpenWrt.

---

## Supported Models & Firmware

| Model | Firmware | OpenWrt | Kernel | Notes |
|-------|----------|---------|--------|-------|
| **GL.iNet Flint 3** | 4.9.0 | 23.05-SNAPSHOT | 5.4.213 | `tc-full`, supports `u32` filters |
| **GL.iNet Flint 2** | 4.9.1 | 21.02-SNAPSHOT | 5.4.238 | `tc-tiny`, **no `u32` filters** |
| **GL.iNet Flint 4 / GL-MT6000 family** | 4.9.1 | 21.02-SNAPSHOT | 5.4.238 | `tc-tiny`, **no `u32` filters** |

> The script auto-detects your model. If detection fails, it falls back to Flint 2-safe settings.

---

## Quick Start

```sh
# One-liner install
curl -fsSL https://raw.githubusercontent.com/wickedyoda/Glinet-Bandwidth-script/main/install.sh | sh

# Run interactive setup
/usr/local/sbin/glinet-vlan-qos-setup.sh
```

The setup wizard will:
1. Ask you to select your model or auto-detect
2. Let you choose persistence mode
3. Show detected VLANs/SSIDs and let you assign priority order
4. Apply the configuration and verify it's working

---

## How It Works

1. **Auto-detects** Flint 2 vs Flint 3 at runtime
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

# Manual control
glinet-vlan-qos.sh start|stop|restart|status|detect|install|uninstall
```

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

## Requirements

- GL.iNet Flint 2 or Flint 3
- OpenWrt 21.02+
- Packages: `tc-full` or `tc-tiny`, `kmod-sched-cake`, `sqm-scripts`
- Root SSH access

---

## License

MIT — feel free to fork and adapt for your GL.iNet setup.
