# Persistence

## Overview

Persistence ensures QoS settings survive reboots, network changes, and firmware upgrades.

---

## Enabled Mode (`PERSISTENT=1`)

When you enable persistence during setup, the script installs three components:

### 1. Boot Hook (`/etc/rc.local`)
```bash
# VLAN QoS persistence
if [ -x /usr/local/sbin/glinet-vlan-qos.sh ]; then
  /usr/local/sbin/glinet-vlan-qos.sh start >/dev/null 2>&1 || true
fi
```

### 2. Network Change Hook (`/etc/gl-switch.d/vlan-qos.sh`)
GL.iNet firmware invokes scripts in `/etc/gl-switch.d/` when the physical network switch changes. This hook ensures QoS restarts after switch events.

### 3. Firmware Upgrade Protection (`/etc/sysupgrade.conf.d/glinet-qos.conf`)
```
/usr/local/sbin/glinet-vlan-qos.sh
/etc/gl-qos-vlan.conf
```
OpenWrt's sysupgrade preserves files listed in this directory and in `/etc/sysupgrade.conf`.

---

## Disabled Mode (`PERSISTENT=0`)

No hooks are installed. QoS is applied manually only.

---

## What Survives

| Event | Persistence=1 | Persistence=0 |
|-------|---------------|---------------|
| Reboot | ✅ | ❌ |
| Network switch event | ✅ | ❌ |
| Firmware upgrade | ✅ | ❌ |
| Factory reset | ❌ | ❌ |
| config.load changes | ✅ | ❌ |

---

## Manual Verification

Check if persistence is installed:
```sh
# Boot hook
grep -l glinet-vlan-qos.sh /etc/rc.local 2>/dev/null

# Network hook  
ls -la /etc/gl-switch.d/vlan-qos.sh

# Upgrade protection
cat /etc/sysupgrade.conf.d/glinet-qos.conf
ls -la /lib/upgrade/retain.d/ 2>/dev/null
```

---

## Manual Control

```sh
# Apply QoS
/etc/gl-switch.d/vlan-qos.sh start

# Or run directly
/usr/local/sbin/glinet-vlan-qos.sh start

# Check status
tc qdisc show dev eth0
nft list table inet gl-qos
```