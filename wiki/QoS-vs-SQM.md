# QoS vs SQM

This script supports two shaping modes. The mode is chosen in Step 0 of the setup wizard and stored in `/etc/gl-qos-vlan.conf`.

## QoS mode

QoS mode assigns traffic classes by bridge or interface. It creates an HTB root qdisc on each selected interface and maps traffic to priority classes using nft marks.

This is the right choice when you want:

- LAN devices to have higher priority than IoT or Guest devices
- Tailscale traffic treated as high-priority management traffic
- Per-SSID or per-VLAN priority instead of simple overall limits

In QoS mode, the script:

- Creates HTB classes for each bridge
- Applies CAKE as a leaf qdisc on each class when enabled
- Sets nft marks in the `preraw` chain based on ingress interface name

## SQM mode

SQM mode uses CAKE on the WAN side to reduce bufferbloat. It is simpler than per-VLAN QoS and does not create separate classes for LAN, IoT, and Guest.

This is the right choice when you want:

- Simple overall bandwidth shaping
- Bufferbloat reduction without VLAN priority rules
- A configuration closer to standard OpenWrt `sqm-scripts` behavior

In SQM mode, the script:

- Applies CAKE directly on the WAN interface
- Uses simpler tc configuration without per-bridge HTB classes
- Skips the VLAN/SSID priority mapping step

## When to use which

- Use **QoS** if you have multiple VLANs or SSIDs and care which traffic wins under congestion.
- Use **SQM** if you mostly want smoother latency and do not need per-VLAN priority.
