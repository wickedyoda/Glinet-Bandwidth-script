# Persistence

Persistence controls whether QoS/SQM is reapplied automatically after reboots, network restarts, and firmware upgrades.

## Persistent mode

When persistence is enabled, the script installs two hooks:

- `/etc/gl-switch.d/vlan-qos.sh` — runs after GL.iNet network switches or WiFi restarts
- `/etc/rc.local` entry — runs during boot

This means QoS survives:

- Router reboots
- Firmware upgrades
- UI-triggered network changes

It does not survive:

- Factory reset

If you factory reset the router, you will need to rerun the setup wizard.

## Manual/Testing mode

When persistence is disabled, no startup hooks are installed. The configuration remains active until:

- Reboot
- Firmware upgrade
- Manual stop/restart that removes qdiscs

Use this mode when:

- You are testing the script on a new model
- You only want temporary shaping
- You want to verify behavior before committing to auto-start

## Checking persistence

```sh
# Verify startup hook exists
ls -la /etc/gl-switch.d/vlan-qos.sh

# Verify boot entry exists
grep glinet-vlan-qos /etc/rc.local

# Test persistence manually
/etc/gl-switch.d/vlan-qos.sh
```

## Removing persistence

Run the uninstall command from the main script:

```sh
glinet-vlan-qos.sh uninstall
```

This removes startup hooks and the installed script files.
