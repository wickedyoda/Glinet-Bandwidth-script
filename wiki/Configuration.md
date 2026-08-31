# Configuration

Edit `/etc/gl-qos-vlan.conf` on the router or use the setup wizard.

---

## Main Settings

```bash
# WAN bandwidth limits (kilobits per second)
WAN_BW_UP=100000          # 100 Mbps upload
WAN_BW_DOWN=500000        # 500 Mbps download

# Traffic shaping mode
QOS_MODE=qos              # or 'sqm'

# Router model (auto-detected if not set)
QOS_MODEL=flint3          # flint2, flint3, flint4, slate7, slate7pro, beryl7, flint3e
```

---

## Per-VLAN Limits

```bash
# LAN bandwidth (br-lan + tailscale0 combined)
QOS_LAN_BW_UP=200000      # 200 Mbps
QOS_LAN_BW_DOWN=500000    # 500 Mbps

# IoT devices (br-iot)
QOS_IOT_BW_UP=100000      # 100 Mbps
QOS_IOT_BW_DOWN=200000    # 200 Mbps

# Guest network (br-guest)
QOS_GUEST_BW_UP=100000    # 100 Mbps
QOS_GUEST_BW_DOWN=200000  # 200 Mbps

# Tailscale mesh
QOS_TAILSCALE_BW_UP=200000    # 200 Mbps
QOS_TAILSCALE_BW_DOWN=500000  # 500 Mbps
```

---

## Advanced Settings

```bash
# Enable CAKE leaf qdisc on all classes
CAKE_ENABLE=1

# Persistence mode
PERSISTENT=1              # 0=disabled, 1=enabled

# Debug logging
DEBUG=0
```

---

## Applying Changes

```sh
# Reload config
source /etc/gl-qos-vlan.conf

# Reapply QoS
/usr/local/sbin/glinet-vlan-qos.sh restart

# Or just stop/start
/usr/local/sbin/glinet-vlan-qos.sh stop
/usr/local/sbin/glinet-vlan-qos.sh start
```

---

## Quick Reference

| Command | Effect |
|---------|--------|
| `qos.sh status` | Show current settings |
| `qos.sh detect` | Show detected model |
| `qos.sh start` | Apply QoS |
| `qos.sh stop` | Remove all QoS |
| `qos.sh restart` | Stop then start |
| `qos.sh uninstall` | Remove all traces |