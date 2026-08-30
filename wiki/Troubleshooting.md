# Troubleshooting

## Model detection fails

If the setup wizard cannot detect your model, it warns you and asks whether to continue with Flint 2-safe defaults.

To investigate:

```sh
cat /etc/board.json | grep -i '"id"'
```

If you know your model, select it manually in the wizard instead of using auto-detect.

If you must run non-interactively, set the model manually:

```sh
export QOS_MODEL=flint2
glinet-vlan-qos.sh start
```

## QoS looks like it did nothing

Check what the script actually applied:

```sh
# Show HTB qdiscs
tc qdisc show dev br-lan
tc qdisc show dev br-iot
tc qdisc show dev br-guest
tc qdisc show dev tailscale0

# Show classes
tc class show dev br-lan

# Show nft marks
nft list table inet gl-qos
```

If qdiscs are missing, rerun the setup wizard or run:

```sh
glinet-vlan-qos.sh start
```

## Flint 2 / Flint 4 / Slate 7 Pro / Beryl 7 shows no `u32` filters

This is expected on `tc-tiny` devices. These models use a simpler tc implementation without `u32` filter support. The script skips `u32` automatically and still applies HTB + nft marking.

## Persistence does not survive reboot

Check both persistence paths:

```sh
ls -la /etc/gl-switch.d/vlan-qos.sh
grep glinet-vlan-qos /etc/rc.local
```

If either is missing, rerun the setup wizard and choose persistent mode, or manually reinstall:

```sh
glinet-vlan-qos.sh install
```

## Bridge not shaped

If a bridge is missing from `tc qdisc show`, verify that the interface exists:

```sh
ip -br link show type bridge
ls -d /sys/class/net/br-lan /sys/class/net/br-iot /sys/class/net/br-guest /sys/class/net/tailscale0 2>/dev/null
```

The script only shapes interfaces that exist. If `br-iot` is missing, it will not create a qdisc for it.

## Need to remove all changes

Run:

```sh
glinet-vlan-qos.sh stop
glinet-vlan-qos.sh uninstall
```

This removes:

- HTB qdiscs
- nft table `inet gl-qos`
- persistence hooks
- installed script files
