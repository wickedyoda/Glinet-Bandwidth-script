# GL.iNet Flint 3 — VLAN/SSID QoS Script

Per-VLAN and per-SSID bandwidth priority for **GL.iNet Flint 3** using **HTB + CAKE** on OpenWrt 23.05.

| VLAN/Bridge | SSIDs | Priority | Default Bandwidth |
|-------------|-------|----------|-------------------|
| `br-lan` + `tailscale0` | `FREEPIZZA`, MLO + Tailscale mesh | **Top** | 200/100 Mbps up/down |
| `br-iot` | `Side_Salad_IOT` | Medium | 50/100 Mbps up/down |
| `br-guest` | `Cheese_Sticks` (guest) | Low/best-effort | 20/50 Mbps up/down |

---

## Supported Hardware & Firmware

| Device | Firmware | OpenWrt | Kernel |
|--------|----------|---------|--------|
| **GL.iNet Flint 3** | 4.9.0 | 23.05-SNAPSHOT | 5.4.213 |

> Tested on Flint 3 with MediaTek MT7986. Other GL.iNet models may need interface/bridge name adjustments.

---

## How It Works

1. **HTB root qdisc** on each bridge/interface
2. **Priority classes**:
   - Class 10 (`prio 1`): LAN + Tailscale — highest priority
   - Class 20 (`prio 2`): IoT — medium priority
   - Class 30 (`prio 3`): Guest — lowest priority
3. **CAKE leaf qdisc** for smart queue management
4. **nft marks** by ingress interface for traffic classification
5. **Persistence** via `/etc/gl-switch.d/` + `/etc/rc.local`

---

## Installation

### Quick Install (one-liner)
```sh
curl -fsSL https://raw.githubusercontent.com/wickedyoda/Glinet-Bandwidth-script/main/install.sh | sh
```

### Manual Install
```sh
# Copy script to router
scp -P 122 glinet-vlan-qos.sh root@flint3:/usr/local/sbin/
ssh -p 122 root@flint3 "chmod +x /usr/local/sbin/glinet-vlan-qos.sh"

# Start QoS
/usr/local/sbin/glinet-vlan-qos.sh start

# Install persistence hooks
/usr/local/sbin/glinet-vlan-qos.sh install
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

# Install persistence hooks
glinet-vlan-qos.sh install

# Remove persistence hooks
glinet-vlan-qos.sh uninstall
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

- GL.iNet Flint 3
- OpenWrt 23.05
- Packages: `tc-full`, `kmod-sched-cake`, `sqm-scripts`
- Root SSH access

---

## Troubleshooting

**QoS not applying:**
```sh
# Check if tc is installed
which tc || opkg install tc-full

# Check if cake module is loaded
lsmod | grep cake || modprobe sch_cake

# Check logs
logread | grep glinet-vlan-qos
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
