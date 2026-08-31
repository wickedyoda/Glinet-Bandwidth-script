# QoS vs SQM

## Which Mode Should You Choose?

### Choose QoS if you have:
- Multiple VLANs or SSIDs with different needs
- WAN upload bandwidth to prioritize
- Need hard caps per network segment
- Tailscale mesh traffic that needs priority

**Best for**: "LAN has priority over Guest during video calls"

### Choose SQM if you have:
- Single WAN connection with bufferbloat issues
- Simple home network without VLAN priorities
- Want automatic queue management
- Need fairness across all devices

**Best for**: "I want my uploads to not choke my download"

---

## Technical Differences

| Feature | QoS Mode | SQM Mode |
|---------|----------|----------|
| Architecture | WAN-rooted HTB + per-VLAN classes | Single WAN CAKE qdisc |
| Priority Classes | LAN > IoT > Guest | All traffic equal (flow-based) |
| Upload Shaping | Hard cap + priority | CAKE handles automatically |
| Download Shaping | Via bridge-level shaping | Not implemented |
| Tailscale Priority | Yes (highest) | No |
| nft Classification | Yes (fwmark → tc fw filter) | No |
| Use Case | Multi-VLAN, business | Home, bufferbloat |

---

## Implementation

### QoS Mode
```
WAN egress (eth0): HTB root
├── Class 1:10 LAN/tailscale (prio 1) [+ bridge shaping]
├── Class 1:20 IoT (prio 2)
├── Class 1:30 Guest (prio 3)
└── nft marks steer traffic to classes
```

### SQM Mode
```
WAN egress (eth0): CAKE diffserv
- Automatic flow isolation
- CoD (Connection-Oriented Data) prioritization
- Built-in fq_codel algorithm
```