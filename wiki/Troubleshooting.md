# Troubleshooting

## Common Issues

### Model Detection Fails

**Symptom**: "Unknown model" or warning message

**Check**:
```sh
cat /etc/board.json | grep -E '"model"|"name"'
```

**Fix**: Select your model manually in the wizard (Step 1-7) or set:
```sh
export QOS_MODEL=flint3
```

---

### WAN Egress Not Shaped

**Symptom**: Upload bandwidth not limited

**Check**:
```sh
tc qdisc show dev eth0
tc class show dev eth0
nft list table inet gl-qos
```

**Fix**:
```sh
# Verify WAN interface detected
ip addr show | grep UP
grep WAN_IF /etc/gl-qos-vlan.conf

# Restart QoS
/usr/local/sbin/glinet-vlan-qos.sh restart
```

---

### CAKE Not Attaching

**Symptom**: `tc qdisc show` shows no CAKE leafs

**Check**:
```sh
dmesg | grep -i cake
tc qdisc show dev eth0
```

**Fix**: The script now uses valid `cake ethernet` keyword. If issues persist:
```sh
# Manual CAKE attachment
tc qdisc add dev eth0 parent 1:10 handle 10: cake ethernet besteffort
```

---

### Persistence Not Working

**Symptom**: QoS stops after reboot or upgrade

**Check**:
```sh
# Boot hook
ls -la /etc/rc.local | grep qos

# Network hook
ls -la /etc/gl-switch.d/vlan-qos.sh

# Upgrade protection
cat /etc/sysupgrade.conf.d/glinet-qos.conf
```

**Fix**: Run setup wizard with persistence enabled or manually:
```sh
echo '# VLAN QoS' >> /etc/rc.local
echo 'if [ -x /usr/local/sbin/glinet-vlan-qos.sh ]; then' >> /etc/rc.local
echo '  /usr/local/sbin/glinet-vlan-qos.sh start' >> /etc/rc.local
echo 'fi' >> /etc/rc.local
```

---

### fwmark/Traffic Classification Not Working

**Symptom**: Wrong traffic gets wrong priority

**Check**:
```sh
nft list table inet gl-qos
tc filter show dev eth0 | grep -E "handle|fwmark"
```

**Fix**: 
```sh
# Flush and restart
nft delete table inet gl-qos 2>/dev/null || true
/usr/local/sbin/glinet-vlan-qos.sh restart

# Verify marks
nft list table inet gl-qos
```

---

## Debugging Commands

```sh
# Full status
/usr/local/sbin/glinet-vlan-qos.sh status

# Model detection
/usr/local/sbin/glinet-vlan-qos.sh detect

# Show all qdiscs
tc qdisc show

# Show all classes
tc class show

# Show nft table
nft list table inet gl-qos

# Router logs
logread | grep gl-qos
```