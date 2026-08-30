#!/bin/sh
#
# glinet-vlan-qos.sh — Per-VLAN/SSID QoS for GL.iNet Flint 2 / Flint 3
# Uses HTB root on main bridges, then fq_codel/cake leaf classes.
# Automatically detects model and skips u32 filters on Flint 2.
#
# Usage:
#   glinet-vlan-qos.sh start|stop|restart|status
#   glinet-vlan-qos.sh install|uninstall
#   glinet-vlan-qos.sh detect   # show detected model
#
# Persistence options:
#   PERSISTENT=1  -> restore on boot via rc.local + gl-switch.d
#   PERSISTENT=0  -> manual/scripted only, survives UI changes but not factory reset
#
# Supported models:
#   - GL.iNet Flint 3 (OpenWrt 23.05, tc-full)
#   - GL.iNet Flint 2 (OpenWrt 21.02, tc-tiny, no u32)
#
# Repo: https://github.com/wickedyoda/Glinet-Bandwidth-script
#

set -u

SCRIPT_NAME="$(basename "$0")"
STATE_DIR="/var/run/${SCRIPT_NAME%.sh}"
CONF_FILE="/etc/config/${SCRIPT_NAME%.sh}"
[ -f /etc/gl-qos-vlan.conf ] && CONF_FILE="/etc/gl-qos-vlan.conf"

# ---------- Model detection ----------
detect_model() {
  # Preferred: board.json model id, available on most GL.iNet builds
  local bid
  bid=$(grep -o '"id": "[^"]*"' /etc/board.json 2>/dev/null | head -1 | sed 's/"id": "//;s/"//') || true
  case "$bid" in
    glinet,gl-mt6000|glinet,gl-mt2500|glinet,gl-mt3000) echo "flint2" ; return ;;
    *be9300*|*ipq53*|*glinet,gl-*) echo "flint3" ; return ;;
  esac

  # Fallback: OpenWrt release target strings
  if grep -q "ipq53xx" /etc/openwrt_release 2>/dev/null; then
    echo "flint3"
  elif grep -q "mediatek/mt7986" /etc/openwrt_release 2>/dev/null; then
    echo "flint2"
  elif [ -f /etc/glversion ]; then
    local ver
    ver=$(cat /etc/glversion 2>/dev/null || echo "")
    case "$ver" in
      4.[89].*|4.[0-8].*) echo "flint2" ;;
      *) echo "unknown" ;;
    esac
  else
    echo "unknown"
  fi
}

MODEL="$(detect_model)"

# ---------- Model-specific tunables ----------
case "$MODEL" in
  flint3)
    : "${QOS_LAN_BW_UP:=200000}"
    : "${QOS_LAN_BW_DOWN:=500000}"
    : "${QOS_IOT_BW_UP:=50000}"
    : "${QOS_IOT_BW_DOWN:=100000}"
    : "${QOS_GUEST_BW_UP:=20000}"
    : "${QOS_GUEST_BW_DOWN:=50000}"
    : "${QOS_TAILSCALE_BW_UP:=50000}"
    : "${QOS_TAILSCALE_BW_DOWN:=100000}"
    : "${USE_U32_FILTERS:=1}"
    ;;
  flint2)
    : "${QOS_LAN_BW_UP:=100000}"
    : "${QOS_LAN_BW_DOWN:=300000}"
    : "${QOS_IOT_BW_UP:=30000}"
    : "${QOS_IOT_BW_DOWN:=80000}"
    : "${QOS_GUEST_BW_UP:=10000}"
    : "${QOS_GUEST_BW_DOWN:=30000}"
    : "${QOS_TAILSCALE_BW_UP:=30000}"
    : "${QOS_TAILSCALE_BW_DOWN:=80000}"
    : "${USE_U32_FILTERS:=0}"
    ;;
  *)
    : "${QOS_LAN_BW_UP:=100000}"
    : "${QOS_LAN_BW_DOWN:=300000}"
    : "${QOS_IOT_BW_UP:=30000}"
    : "${QOS_IOT_BW_DOWN:=80000}"
    : "${QOS_GUEST_BW_UP:=10000}"
    : "${QOS_GUEST_BW_DOWN:=30000}"
    : "${QOS_TAILSCALE_BW_UP:=30000}"
    : "${QOS_TAILSCALE_BW_DOWN:=80000}"
    : "${USE_U32_FILTERS:=0}"
    ;;
esac

: "${CAKE_ENABLE:=1}"
: "${PERSISTENT:=1}"
: "${FWMARK_LAN:=0x00010000}"
: "${FWMARK_IOT:=0x00020000}"
: "${FWMARK_GUEST:=0x00030000}"
: "${FWMARK_TAILSCALE:=0x00040000}"

log_info()  { logger -t "$SCRIPT_NAME" "[INFO] $*"; }
log_warn()  { logger -t "$SCRIPT_NAME" "[WARN] $*"; }
log_err()   { logger -t "$SCRIPT_NAME" "[ERROR] $*"; }

has_tc() { command -v tc >/dev/null 2>&1; }
has_nft() { command -v nft >/dev/null 2>&1; }

load_conf() {
  [ -f "$CONF_FILE" ] && . "$CONF_FILE"
}

save_mark_rules() {
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

add_qdisc_htb() {
  local dev="$1" handle="$2" default="$3"
  tc qdisc add dev "$dev" handle "$handle:" root htb default "$default" 2>/dev/null || \
    tc qdisc change dev "$dev" handle "$handle:" root htb default "$default" 2>/dev/null || true
}

add_htb_class() {
  local dev="$1" parent="$2" classid="$3" rate="$4" ceil="$5" burst="$6" prio="$7"
  tc class add dev "$dev" parent "$parent" classid "$classid" htb rate "${rate}kbit" ceil "${ceil}kbit" burst "${burst}" prio "$prio" 2>/dev/null || \
    tc class change dev "$dev" parent "$parent" classid "$classid" htb rate "${rate}kbit" ceil "${ceil}kbit" burst "${burst}" prio "$prio" 2>/dev/null || true
}

add_cake_leaf() {
  local dev="$1" parent="$2" handle="$3" args="$4"
  [ "${CAKE_ENABLE}" != "1" ] && return 0
  tc qdisc add dev "$dev" parent "$parent" handle "$handle:" cake ethernet atm-overhead $args 2>/dev/null || true
}

add_u32_filter() {
  # Only on Flint 3 / tc-full
  [ "${USE_U32_FILTERS}" != "1" ] && return 0
  local dev="$1" parent="$2" pref="$3" src="$4" flowid="$5"
  tc filter add dev "$dev" parent "$parent" protocol ip pref "$pref" u32 \
    match ip src "$src" flowid "$flowid" 2>/dev/null || true
}

apply_qos() {
  local action="$1"

  case "$action" in
    start|restart)
      if ! has_tc; then
        log_err "tc not found; install tc-full or tc-tiny"
        return 1
      fi

      stop >/dev/null 2>&1 || true

      log_info "Applying QoS on ${MODEL} (lan=${QOS_LAN_BW_UP}/${QOS_LAN_BW_DOWN} iot=${QOS_IOT_BW_UP}/${QOS_IOT_BW_DOWN} guest=${QOS_GUEST_BW_UP}/${QOS_GUEST_BW_DOWN})"

      # ---------- br-lan ----------
      if [ -d /sys/class/net/br-lan ]; then
        add_qdisc_htb br-lan 1 30
        add_htb_class br-lan 1: 1:1 "$QOS_LAN_BW_UP" "$QOS_LAN_BW_UP" 1500 1
        add_htb_class br-lan 1:1 1:10 "$QOS_LAN_BW_UP" "$QOS_LAN_BW_UP" 1500 1
        add_cake_leaf br-lan 1:10 10 "besteffort triple-isolate"
        add_htb_class br-lan 1:1 1:20 "$QOS_IOT_BW_UP" "$QOS_IOT_BW_UP" 1500 2
        add_cake_leaf br-lan 1:20 20 "besteffort"
        add_htb_class br-lan 1:1 1:30 "$QOS_GUEST_BW_UP" "$QOS_GUEST_BW_UP" 1500 3
        add_cake_leaf br-lan 1:30 30 "besteffort"
        tc qdisc add dev br-lan handle ffff: ingress 2>/dev/null || true
        add_u32_filter br-lan ffff: 10 "192.168.61.0/24" 1:10
      fi

      # ---------- br-iot ----------
      if [ -d /sys/class/net/br-iot ]; then
        add_qdisc_htb br-iot 2 20
        add_htb_class br-iot 2: 2:1 "$QOS_IOT_BW_UP" "$QOS_IOT_BW_UP" 1500 2
        add_htb_class br-iot 2:1 2:20 "$QOS_IOT_BW_UP" "$QOS_IOT_BW_UP" 1500 2
        add_cake_leaf br-iot 2:20 20 "besteffort"
      fi

      # ---------- br-guest ----------
      if [ -d /sys/class/net/br-guest ]; then
        add_qdisc_htb br-guest 3 30
        add_htb_class br-guest 3: 3:1 "$QOS_GUEST_BW_UP" "$QOS_GUEST_BW_UP" 1500 3
        add_htb_class br-guest 3:1 3:30 "$QOS_GUEST_BW_UP" "$QOS_GUEST_BW_UP" 1500 3
        add_cake_leaf br-guest 3:30 30 "besteffort"
      fi

      # ---------- tailscale0 ----------
      if [ -d /sys/class/net/tailscale0 ]; then
        add_qdisc_htb tailscale0 4 40
        add_htb_class tailscale0 4: 4:1 "$QOS_TAILSCALE_BW_UP" "$QOS_TAILSCALE_BW_UP" 1500 1
        add_htb_class tailscale0 4:1 4:40 "$QOS_TAILSCALE_BW_UP" "$QOS_TAILSCALE_BW_UP" 1500 1
        add_cake_leaf tailscale0 4:40 40 "besteffort triple-isolate"
      fi

      # ---------- nft / iptables marks ----------
      if has_nft; then
        nft delete table inet gl-qos 2>/dev/null || true
        nft add table inet gl-qos 2>/dev/null || true
        nft add chain inet gl-qos preraw { type filter hook prerouting priority mangle \; policy accept \; } 2>/dev/null || true
        nft add rule inet gl-qos preraw iifname "br-iot" meta mark set "$FWMARK_IOT" 2>/dev/null || true
        nft add rule inet gl-qos preraw iifname "br-guest" meta mark set "$FWMARK_GUEST" 2>/dev/null || true
        nft add rule inet gl-qos preraw iifname "tailscale0" meta mark set "$FWMARK_TAILSCALE" 2>/dev/null || true
        nft add rule inet gl-qos preraw iifname "br-lan" meta mark set "$FWMARK_LAN" 2>/dev/null || true
      fi

      save_mark_rules "$(get_mark_id)"
      log_info "QoS applied on ${MODEL}. LAN+Tailscale=high, IoT=medium, Guest=low."
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
      echo "=== Detected model: ${MODEL} ==="
      echo "=== HTB qdisc ==="
      for dev in br-lan br-iot br-guest tailscale0; do
        [ -d /sys/class/net/$dev ] || continue
        echo "--- $dev ---"
        tc -s qdisc show dev "$dev" 2>/dev/null | head -3 || echo "  none"
      done
      echo "=== nft gl-qos ==="
      nft list table inet gl-qos 2>/dev/null || echo "  not present"
      echo "=== TC filters ==="
      tc filter show dev br-lan 2>/dev/null | grep -E "u32|flowid" | head -5 || echo "  no u32 filters"
      ;;
    *)
      echo "Usage: $0 {start|stop|restart|status|install|uninstall|detect}"
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
if [ -x /usr/local/sbin/glinet-vlan-qos.sh ]; then
  /usr/local/sbin/glinet-vlan-qos.sh start >/dev/null 2>&1 || true
fi
RCEOF
  chmod +x "$hook"
  log_info "Installed network hook: $hook"

  if [ -f "$rc_local" ]; then
    if ! grep -q "glinet-vlan-qos.sh" "$rc_local" 2>/dev/null; then
      cp "$rc_local" "${rc_local}.bak.$(date +%Y%m%d%H%M%S)"
      printf '\n# VLAN QoS persistence\nif [ -x /usr/local/sbin/glinet-vlan-qos.sh ]; then\n  /usr/local/sbin/glinet-vlan-qos.sh start >/dev/null 2>&1 || true\nfi\n' >> "$rc_local"
      log_info "Appended QoS start to $rc_local"
    fi
  fi

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
  detect)
    echo "Detected model: ${MODEL}"
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|install|uninstall|detect}"
    exit 1
    ;;
esac

exit $?
