# GL.iNet Bandwidth Script

Per-VLAN and per-SSID bandwidth priority for **GL.iNet Flint 2** and **GL.iNet Flint 3** using **HTB + CAKE** on OpenWrt.

---

## Supported Models & Firmware

| Model | Firmware | OpenWrt | Kernel | Notes |
|-------|----------|---------|--------|-------|
| **GL.iNet Flint 3** | 4.9.0 | 23.05-SNAPSHOT | 5.4.213 | `tc-full`, supports `u32` filters |
| **GL.iNet Flint 2** | 4.9.1 | 21.02-SNAPSHOT | 5.4.238 | `tc-tiny`, **no `u32` filters** |

> The script auto-detects your model. If detection fails, it falls back to Flint 2-safe settings.

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

## Quick Install

```sh
curl -fsSL https://raw.githubusercontent.com/wickedyoda/Glinet-Bandwidth-script/main/install.sh | sh
```

---

## Usage

```sh
# Start QoS
glinet-vlan-qos.sh start

# Stop QoS
glinet-vlan-qos.sh stop

# Restart QoS
glinet-vlan-qos.sh restart

# Check status
glinet-vlan-qos.sh status

# Run model detection
glinet-vlan-qos.sh detect

# Install persistence hooks
glinet-vlan-qos.sh install

# Remove persistence hooks
glinet-vlan-qos.sh uninstall
```

---

## Model Selection

The script auto-detects your model on first run:

```sh
$ glinet-vlan-qos.sh detect
Detected model: flint3
```

### Manual override (optional)
If auto-detection fails, set the model before starting:

```sh
export QOS_MODEL=flint2   # or flint3
glinet-vlan-qos.sh start
```

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
# 1 = auto-start on network changes/boot (GL.iNet hooks + rc.local)
# 0 = manual only, survives UI changes but not factory reset
PERSISTENT=1
```

---

## Default Bandwidth by Model

| Model | LAN | IoT | Guest | Tailscale |
|-------|-----|-----|-------|-----------|
| **Flint 3** | 200/500 Mbps | 50/100 Mbps | 20/50 Mbps | 50/100 Mbps |
| **Flint 2** | 100/300 Mbps | 30/80 Mbps | 10/30 Mbps | 30/80 Mbps |

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

# Check traffic stats
tc -s qdisc show dev br-lan
tc -s class show dev br-lan
```

Expected output:
```
Detected model: flint2

table inet gl-qos {
    chain preraw {
        type filter hook prerouting priority mangle; policy accept;
        iifname "br-iot" meta mark set 0x00020000
        iifname "br-guest" meta mark set 0x00030000
        iifname "tailscale0" meta mark set 0x00040000
        iifname "br-lan" meta mark set 0x00010000
    }
}
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

- GL.iNet Flint 2 or Flint 3
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

**QoS not applying on Flint 2:**
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

## License

MIT — feel free to fork and adapt for your GL.iNet setup.
