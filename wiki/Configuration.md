# Configuration

The setup wizard writes `/etc/gl-qos-vlan.conf` on the router. You can edit this file directly to change bandwidth limits, enable or disable CAKE, or switch persistence behavior without rerunning the full wizard.

## Example configuration

```bash
# Bandwidth limits in kbit/s
QOS_LAN_BW_UP=200000
QOS_LAN_BW_DOWN=500000
QOS_IOT_BW_UP=50000
QOS_IOT_BW_DOWN=100000
QOS_GUEST_BW_UP=20000
QOS_GUEST_BW_DOWN=50000
QOS_TAILSCALE_BW_UP=50000
QOS_TAILSCALE_BW_DOWN=100000

# Enable or disable CAKE leaf qdisc
CAKE_ENABLE=1

# Persistence mode
PERSISTENT=1
```

## Fields

| Field | Purpose |
|-------|---------|
| `QOS_LAN_BW_UP` | Upload limit for `br-lan` |
| `QOS_LAN_BW_DOWN` | Download limit for `br-lan` |
| `QOS_IOT_BW_UP` | Upload limit for `br-iot` |
| `QOS_IOT_BW_DOWN` | Download limit for `br-iot` |
| `QOS_GUEST_BW_UP` | Upload limit for `br-guest` |
| `QOS_GUEST_BW_DOWN` | Download limit for `br-guest` |
| `QOS_TAILSCALE_BW_UP` | Upload limit for `tailscale0` |
| `QOS_TAILSCALE_BW_DOWN` | Download limit for `tailscale0` |
| `CAKE_ENABLE` | `1` enables CAKE, `0` disables it |
| `PERSISTENT` | `1` enables startup hooks, `0` disables them |

## Applying changes

After editing `/etc/gl-qos-vlan.conf`, restart the script to apply the new values:

```sh
glinet-vlan-qos.sh restart
```

## Model defaults

Different models use different default bandwidth values. The main script selects defaults based on detected model and mode. If you want the same behavior across multiple routers, copy the same config file to each device.
