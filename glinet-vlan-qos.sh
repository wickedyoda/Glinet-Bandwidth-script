#!/bin/sh
#
# glinet-vlan-qos.sh — Per-VLAN/SSID QoS for GL.iNet Flint 3
# Uses HTB root on main bridges, then fq_codel leaf classes.
# Intended to be called from /etc/gl-switch.d/ and optionally /etc/rc.local.
#
# Usage:
#   glinet-vlan-qos.sh start|stop|restart|status
#
# Persistence options:
#   PERSISTENT=1  -> restore on boot via rc.local
#   PERSISTENT=0  -> manual/scripted only, survives UI changes but not factory reset
#
# Repo: https://github.com/wickedyoda/glinet-vlan-qos
#

set -u

SCRIPT_NAME="$(basename "$0")"
STATE_DIR="/var/run/${SCRIPT_NAME%.sh}"
CONF_FILE="/etc/config/${SCRIPT_NAME%.sh}"
[ -f /etc/gl-qos-vlan.conf ] && CONF_FILE="/etc/gl-qos-vlan.conf"

# Tunables — edit these or override in /etc/gl-qos-vlan.conf
: "${QOS_LAN_BW_UP:=200000}"
: "${QOS_LAN_BW_DOWN:=500000}"
: "${QOS_IOT_BW_UP:=50000}"
: "${QOS_IOT_BW_DOWN:=100000}"
: "${QOS_GUEST_BW_UP:=20000}"
: "${QOS_GUEST_BW_DOWN:=50000}"
: "${QOS_TAILSCALE_BW_UP:=50000}"
: "${QOS_TAILSCALE_BW_DOWN:=100000}"
: "${CAKE_ENABLE:=1}"
: "${PERSISTENT:=1}"

log_info()  { logger -t "$SCRIPT_NAME" "[INFO] $*"; }
log_warn()  { logger -t "$SCRIPT_NAME" "[WARN] $*"; }
log_err()   { logger -t "$SCRIPT_NAME" "[ERROR] $*"; }

has_tc() { command -v tc >/dev/null 2>&1; }
has_nft() { command -v nft >/dev/null 2>&1; }

load_conf() {
  [ -f "$CONF_FILE" ] && . "$CONF_FILE"
}

save_mark_rules() {
  # Save a marker so we can delete our own rules later
  mkdir -p "$STATE_DIR"
  echo "$1" > "${STATE_DIR}/mark_id"
}

get_mark_id() {
  if [ -f "${STATE_DIR}/mark_id" ]; then
    cat "${STATE_DIR}/mark_id"
  else
    echo "0x100"
  fi
}

apply_qos() {
  local action="$1"
  local mark_base
  mark_base="$(get_mark_id)"

  case "$action" in
    start|restart)
      if ! has_tc; then
        log_err "tc not found; install tc-full or kmod-sched"
        return 1
      fi

      # Clean any previous instance from this script
      stop >/dev/null 2>&1 || true

      log_info "Applying HTB+CAKE QoS (lan=${QOS_LAN_BW_UP}/${QOS_LAN_BW_DOWN} iot=${QOS_IOT_BW_UP}/${QOS_IOT_BW_DOWN} guest=${QOS_GUEST_BW_UP}/${QOS_GUEST_BW_DOWN})"

      # ---------- br-lan ----------
      if [ -d /sys/class/net/br-lan ]; then
        tc qdisc add dev br-lan handle 1: root htb default 30 2>/dev/null || \
          tc qdisc change dev br-lan handle 1: root htb default 30 2>/dev/null || true

        tc class add dev br-lan parent 1: classid 1:1 htb rate "${QOS_LAN_BW_UP}kbit" burst 1500 2>/dev/null || \
          tc class change dev br-lan parent 1: classid 1:1 htb rate "${QOS_LAN_BW_UP}kbit" burst 1500 2>/dev/null || true

        # Priority 10: LAN/Tailscale
        tc class add dev br-lan parent 1:1 classid 1:10 htb rate "${QOS_LAN_BW_UP}kbit" burst 1500 prio 1 2>/dev/null || \
          tc class change dev br-lan parent 1:1 classid 1:10 htb rate "${QOS_LAN_BW_UP}kbit" burst 1500 prio 1 2>/dev/null || true
        [ "${CAKE_ENABLE}" = "1" ] && \
          tc qdisc add dev br-lan parent 1:10 handle 10: cake ethernet atm-overhead besteffort triple-isolate 2>/dev/null || true

        # Priority 20: IoT
        tc class add dev br-lan parent 1:1 classid 1:20 htb rate "${QOS_IOT_BW_UP}kbit" burst 1500 prio 2 2>/dev/null || \
          tc class change dev br-lan parent 1:1 classid 1:20 htb rate "${QOS_IOT_BW_UP}kbit" burst 1500 prio 2 2>/dev/null || true
        [ "${CAKE_ENABLE}" = "1" ] && \
          tc qdisc add dev br-lan parent 1:20 handle 20: cake ethernet atm-overhead besteffort 2>/dev/null || true

        # Priority 30: Guest (default)
        tc class add dev br-lan parent 1:1 classid 1:30 htb rate "${QOS_GUEST_BW_UP}kbit" burst 1500 prio 3 2>/dev/null || \
          tc class change dev br-lan parent 1:1 classid 1:30 htb rate "${QOS_GUEST_BW_UP}kbit" burst 1500 prio 3 2>/dev/null || true
        [ "${CAKE_ENABLE}" = "1" ] && \
          tc qdisc add dev br-lan parent 1:30 handle 30: cake ethernet atm-overhead besteffort 2>/dev/null || true

        # Egress shaping for download direction on br-lan
        tc qdisc add dev br-lan handle ffff: ingress 2>/dev/null || true
        tc filter add dev br-lan parent ffff: protocol ip prio 10 u32 \
          match ip src 192.168.61.0/24 flowid 1:10 2>/dev/null || true
      fi

      # ---------- br-iot ----------
      if [ -d /sys/class/net/br-iot ]; then
        tc qdisc add dev br-iot handle 2: root htb default 20 2>/dev/null || \
          tc qdisc change dev br-iot handle 2: root htb default 20 2>/dev/null || true
        tc class add dev br-iot parent 2: classid 2:1 htb rate "${QOS_IOT_BW_UP}kbit" burst 1500 2>/dev/null || \
          tc class change dev br-iot parent 2: classid 2:1 htb rate "${QOS_IOT_BW_UP}kbit" burst 1500 2>/dev/null || true
        tc class add dev br-iot parent 2:1 classid 2:20 htb rate "${QOS_IOT_BW_UP}kbit" burst 1500 prio 2 2>/dev/null || \
          tc class change dev br-iot parent 2:1 classid 2:20 htb rate "${QOS_IOT_BW_UP}kbit" burst 1500 prio 2 2>/dev/null || true
        [ "${CAKE_ENABLE}" = "1" ] && \
          tc qdisc add dev br-iot parent 2:20 handle 20: cake ethernet atm-overhead besteffort 2>/dev/null || true
      fi

      # ---------- br-guest ----------
      if [ -d /sys/class/net/br-guest ]; then
        tc qdisc add dev br-guest handle 3: root htb default 30 2>/dev/null || \
          tc qdisc change dev br-guest handle 3: root htb default 30 2>/dev/null || true
        tc class add dev br-guest parent 3: classid 3:1 htb rate "${QOS_GUEST_BW_UP}kbit" burst 1500 2>/dev/null || \
          tc class change dev br-guest parent 3: classid 3:1 htb rate "${QOS_GUEST_BW_UP}kbit" burst 1500 2>/dev/null || true
        tc class add dev br-guest parent 3:1 classid 3:30 htb rate "${QOS_GUEST_BW_UP}kbit" burst 1500 prio 3 2>/dev/null || \
          tc class change dev br-guest parent 3:1 classid 3:30 htb rate "${QOS_GUEST_BW_UP}kbit" burst 1500 prio 3 2>/dev/null || true
        [ "${CAKE_ENABLE}" = "1" ] && \
          tc qdisc add dev br-guest parent 3:30 handle 30: cake ethernet atm-overhead besteffort 2>/dev/null || true
      fi

      # ---------- tailscale0 ----------
      if [ -d /sys/class/net/tailscale0 ]; then
        tc qdisc add dev tailscale0 handle 4: root htb default 40 2>/dev/null || \
          tc qdisc change dev tailscale0 handle 4: root htb default 40 2>/dev/null || true
        tc class add dev tailscale0 parent 4: classid 4:1 htb rate "${QOS_TAILSCALE_BW_UP}kbit" burst 1500 2>/dev/null || \
          tc class change dev tailscale0 parent 4: classid 4:1 htb rate "${QOS_TAILSCALE_BW_UP}kbit" burst 1500 2>/dev/null || true
        tc class add dev tailscale0 parent 4:1 classid 4:40 htb rate "${QOS_TAILSCALE_BW_UP}kbit" burst 1500 prio 1 2>/dev/null || \
          tc class change dev tailscale0 parent 4:1 classid 4:40 htb rate "${QOS_TAILSCALE_BW_UP}kbit" burst 1500 prio 1 2>/dev/null || true
        [ "${CAKE_ENABLE}" = "1" ] && \
          tc qdisc add dev tailscale0 parent 4:40 handle 40: cake ethernet atm-overhead besteffort triple-isolate 2>/dev/null || true
      fi

      # ---------- nft / iptables marks ----------
      if has_nft; then
        # Mark packets by ingress interface so downstream tc filters can classify them
        nft add table inet gl-qos 2>/dev/null || true
        nft add chain inet gl-qos preraw { type filter hook prerouting priority mangle \; policy accept \; } 2>/dev/null || true
        nft add rule inet gl-qos preraw iifname "br-iot" meta mark set 0x00020000 2>/dev/null || true
        nft add rule inet gl-qos preraw iifname "br-guest" meta mark set 0x00030000 2>/dev/null || true
        nft add rule inet gl-qos preraw iifname "tailscale0" meta mark set 0x00040000 2>/dev/null || true
        nft add rule inet gl-qos preraw iifname "br-lan" meta mark set 0x00010000 2>/dev/null || true
      fi

      save_mark_rules "$mark_base"
      log_info "QoS applied. LAN=high, IoT=medium, Guest=low."
      ;;

    stop)
      log_info "Removing HTB+CAKE QoS..."

      for dev in br-lan br-iot br-guest tailscale0; do
        [ -d /sys/class/net/$dev ] || continue
        tc qdisc del dev "$dev" root 2>/dev/null || true
        tc qdisc del dev "$dev" ingress 2>/dev/null || true
        tc filter del dev "$dev" parent ffff: protocol ip pref 10 u32 2>/dev/null || true
      done

      if has_nft; then
        nft delete table inet gl-qos 2>/dev/null || true
      fi

      rm -rf "$STATE_DIR" 2>/dev/null || true
      log_info "QoS removed."
      ;;
    status)
      echo "=== HTB qdisc ==="
      for dev in br-lan br-iot br-guest tailscale0; do
        [ -d /sys/class/net/$dev ] || continue
        echo "--- $dev ---"
        tc -s qdisc show dev "$dev" 2>/dev/null || echo "  none"
      done
      echo "=== nft gl-qos ==="
      nft list table inet gl-qos 2>/dev/null || echo "  not present"
      ;;
    *)
      echo "Usage: $0 start|stop|restart|status"
      exit 1
      ;;
  esac
}

# ---------- GL.iNet boot/network persistence hooks ----------
install_persistence() {
  local switch_dir="/etc/gl-switch.d"
  local hook="${switch_dir}/vlan-qos.sh"
  local rc_local="/etc/rc.local"

  if [ ! -d "$switch_dir" ]; then
    log_warn "$switch_dir missing; skipping hook install"
    return 1
  fi

  cat > "$hook" <<'RCEOF'
#!/bin/sh
# glinet-vlan-qos persistence hook
# Runs after network switches/restarts.
if [ -x /usr/local/sbin/glinet-vlan-qos.sh ]; then
  /usr/local/sbin/glinet-vlan-qos.sh start >/dev/null 2>&1 || true
fi
RCEOF
  chmod +x "$hook"
  log_info "Installed network hook: $hook"

  # rc.local fallback
  if [ -f "$rc_local" ]; then
    if ! grep -q "glinet-vlan-qos.sh" "$rc_local" 2>/dev/null; then
      cp "$rc_local" "${rc_local}.bak.$(date +%Y%m%d%H%M%S)"
      printf '\n# VLAN QoS persistence\nif [ -x /usr/local/sbin/glinet-vlan-qos.sh ]; then\n  /usr/local/sbin/glinet-vlan-qos.sh start >/dev/null 2>&1 || true\nfi\n' >> "$rc_local"
      log_info "Appended QoS start to $rc_local"
    fi
  fi

  # Remove persistence if requested
  if [ "${PERSISTENT}" = "0" ]; then
    rm -f "$hook" 2>/dev/null || true
    log_warn "Persistence disabled; QoS will not auto-start on network changes."
  fi
}

remove_persistence() {
  rm -f "/etc/gl-switch.d/vlan-qos.sh" 2>/dev/null || true
  log_info "Removed persistence hook."
}

# ---------- main ----------
load_conf

case "${1:-}" in
  start|stop|restart)
    apply_qos "$1"
    ;;
  install)
    install_persistence
    ;;
  uninstall)
    remove_persistence
    apply_qos stop
    ;;
  status)
    apply_qos status
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|install|uninstall}"
    exit 1
    ;;
esac

exit $?
