# Troubleshooting

**Detection fails**
```sh
cat /etc/board.json | grep model
export QOS_MODEL=flint2
glinet-vlan-qos.sh start
```

**Flint 2/4 tc-tiny**
- No `u32` filters are expected.
- Verify with `tc class show dev br-lan`.

**Persistence**
```sh
ls -la /etc/gl-switch.d/vlan-qos.sh
/etc/gl-switch.d/vlan-qos.sh
```
