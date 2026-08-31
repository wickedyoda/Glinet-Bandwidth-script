# Setup Wizard

Run the setup wizard on your router:

```sh
glinet-vlan-qos-setup.sh
```

## Wizard Steps

### Step 0: Traffic Shaping Mode
- **QoS (default)**: WAN-rooted HTB with per-VLAN priority classes
- **SQM**: CAKE diffserv at measured WAN bandwidth for bufferbloat reduction

### Step 1: Router Model
Select your model or choose auto-detect:
1. Flint 2 (GL-MT6000)
2. Flint 3 (GL-BE9300)
3. Flint 4 (GL-BE14000)
4. Slate 7 (GL-BE3600)
5. Slate 7 Pro (GL-BE10000)
6. Beryl 7 (GL-MT3600BE)
7. Flint 3e (GL-BE6500)
8. Auto-detect

### Step 2: Persistence
Install hooks that survive reboots and firmware upgrades:
- Adds to `/etc/rc.local` for boot
- Adds to `/etc/gl-switch.d/vlan-qos.sh` for network changes
- Adds to `/etc/sysupgrade.conf.d/` for firmware upgrades

### Step 3: WAN Bandwidth
Set your actual WAN limits:
- Upload (kbps)
- Download (kbps)

### Step 4: Bridge Priority
Assign priority (1-3, 1=highest) to each bridge:
- `br-lan` (main LAN + WiFi)
- `br-iot` (IoT devices)
- `br-guest` (Guest network)
- `tailscale0` (Tailscale mesh)

### Step 5: Summary & Apply
Review settings and apply. The script verifies qdisc and nft rules.

## Uninstall

To remove QoS and all traces:

```sh
glinet-vlan-qos-setup.sh uninstall
```

Or directly:
```sh
/usr/local/sbin/glinet-vlan-qos.sh uninstall
```

This removes:
- HTB qdiscs and CAKE leaf qdiscs on WAN and bridges
- All fw filters and nft marks
- `/etc/gl-switch.d/vlan-qos.sh` hook
- `/etc/rc.local` QoS stanza
- `/etc/sysupgrade.conf.d/glinet-qos.conf`
- The scripts themselves from `/usr/local/sbin/`

## Skipping the Wizard

```sh
# Set config manually
echo 'WAN_BW_UP=100000' > /etc/gl-qos-vlan.conf
echo 'WAN_BW_DOWN=500000' >> /etc/gl-qos-vlan.conf
echo 'CAKE_ENABLE=1' >> /etc/gl-qos-vlan.conf

# Apply directly
/usr/local/sbin/glinet-vlan-qos.sh start
```