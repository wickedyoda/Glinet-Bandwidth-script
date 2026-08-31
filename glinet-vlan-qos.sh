#!/bin/sh
# glinet-vlan-qos.sh - Per-VLAN/SSID bandwidth priority for GL.iNet routers
# WAN-rooted HTB + optional bridge shaping + SQM mode
# GPLv3 - see LICENSE

set -euo pipefail

MAIN_SCRIPT="/usr/local/sbin/glinet-vlan-qos.sh"
CONF_FILE="/etc/gl-qos-vlan.conf"
LOG_TAG="gl-qos"
MODEL=""
USE_U32_FILTERS=0
WAN_IF="eth0"
WAN_BW_UP=0
WAN_BW_DOWN=0
QOS_MODE="qos"
PERSISTENT=0
CAKE_ENABLE=1

log_info() { logger -t "$LOG_TAG" -p info "INFO: $*"; }
log_err() { logger -t "$LOG_TAG" -p err "ERR: $*"; echo "ERR: $*" >&2; }

has_tc() { command -v tc >/dev/null 2>&1; }
has_nft() { command -v nft >/dev/null 2>&1; }

# ---------- Model detection ----------
detect_model() {
  local board="$(cat /etc/board.json 2>/dev/null || echo '{}')"
  case "$board" in
    *'"glinet,gl-be14000"'*|*'"glinet,gl-mt6000"'*) MODEL="flint2"; USE_U32_FILTERS=0 ;;
    *'"qcom,ipq5332-ap-mi01.6"'*) MODEL="flint3"; USE_U32_FILTERS=1 ;;
    *'"glinet,gl-be3600"'*) MODEL="flint3"; USE_U32_FILTERS=1 ;;
    *'"glinet,gl-be10000"'*) MODEL="flint2"; USE_U32_FILTERS=0 ;;
    *'"glinet,gl-mt3600be"'*) MODEL="flint2"; USE_U32_FILTERS=0 ;;
    *'"qcom,ipq5332-ap-mi04.1-v1"'*) MODEL="flint3"; USE_U32_FILTERS=1 ;;
    *) MODEL="unknown"; USE_U32_FILTERS=0 ;;
  esac
  echo "Detected model: $MODEL"
}

# ---------- Config loading ----------
load_config() {
  [ -f "$CONF_FILE" ] && . "$CONF_FILE" || true
  : "${WAN_BW_UP:=0}"
  : "${WAN_BW_DOWN:=0}"
  : "${QOS_LAN_BW_UP:=200000}"
  : "${QOS_LAN_BW_DOWN:=500000}"
  : "${QOS_IOT_BW_UP:=100000}"
  : "${QOS_IOT_BW_DOWN:=200000}"
  : "${QOS_GUEST_BW_UP:=100000}"
  : "${QOS_GUEST_BW_DOWN:=200000}"
  : "${QOS_TAILSCALE_BW_UP:=200000}"
  : "${QOS_TAILSCALE_BW_DOWN:=500000}"
  : "${QOS_MODE:=qos}"
  : "${CAKE_ENABLE:=1}"
  : "${PERSISTENT:=0}"
}

# ---------- WAN detection ----------
detect_wan() {
  local def
  def="$(ip route show default 2>/dev/null | head -n1 | awk '{print $5}')"
  [ -n "$def" ] && WAN_IF="$def"
  [ -d "/sys/class/net/$WAN_IF" ] || WAN_IF="eth0"
  echo "WAN interface: $WAN_IF"
}

# ---------- HTB helpers ----------
add_qdisc_htb() {
  local dev="$1" handle="$2" default="$3"
  tc qdisc add dev "$dev" handle "$handle:" root htb default "$default" 2>/dev/null || \
    tc qdisc change dev "$dev" handle "$handle:" root htb default "$default" 2>/dev/null || \
    log_err "Failed to set HTB qdisc on $dev"
}

add_htb_class() {
  local dev="$1" parent="$2" classid="$3" rate="$4" ceil="$5" burst="$6" prio="$7"
  tc class add dev "$dev" parent "$parent" classid "$classid" htb rate "${rate}kbit" ceil "${ceil}kbit" burst "${burst}" prio "$prio" 2>/dev/null || \
    tc class change dev "$dev" parent "$parent" classid "$classid" htb rate "${rate}kbit" ceil "${ceil}kbit" burst "${burst}" prio "$prio" 2>/dev/null || \
    log_err "Failed to add/change class $classid on $dev"
}

add_cake_leaf() {
  [ "${CAKE_ENABLE}" != "1" ] && return 0
  local dev="$1" parent="$2" handle="$3" args="$4"
  tc qdisc add dev "$dev" parent "$parent" handle "$handle:" cake ethernet $args 2>/dev/null || \
    log_err "Failed to attach CAKE to $dev parent $parent handle $handle"
}

add_fw_filter() {
  local dev="$1" parent="$2" pref="$3" mark="$4" flowid="$5"
  [ "$USE_U32_FILTERS" = "1" ] || return 0
  tc filter add dev "$dev" parent "$parent" protocol ip pref "$pref" handle "$mark" fw flowid "$flowid" 2>/dev/null || \
    log_err "Failed to add fw filter mark $mark on $dev"
}

# ---------- nft classification ----------
setup_nft() {
  has_nft || return 0
  nft delete table inet gl-qos 2>/dev/null || true
  nft add table inet gl-qos 2>/dev/null || true
  nft add chain inet gl-qos mangle_out { type filter hook output priority mangle \; policy accept \; } 2>/dev/null || true
  nft add rule inet gl-qos mangle_out oifname "$WAN_IF" meta mark set 0x10 2>/dev/null || true
}

# ---------- WAN-rooted QoS ----------
apply_wan_rooted_qos() {
  local action="$1"
  [ "$WAN_BW_UP" -gt 0 ] || { log_err "WAN_BW_UP not set; cannot apply WAN-rooted QoS"; return 1; }

  case "$action" in
    start|restart)
      stop >/dev/null 2>&1 || true
      log_info "Applying WAN-rooted QoS on $WAN_IF up=${WAN_BW_UP} down=${WAN_BW_DOWN} mode=$QOS_MODE model=$MODEL"
      detect_wan
      setup_nft

      # Root on WAN egress
      add_qdisc_htb "$WAN_IF" 1 10
      add_htb_class "$WAN_IF" 1: 1:1 "$WAN_BW_UP" "$WAN_BW_UP" 1500 1

      # LAN class
      add_htb_class "$WAN_IF" 1:1 1:10 "$QOS_LAN_BW_UP" "$WAN_BW_UP" 1500 1
      add_fw_filter "$WAN_IF" 1: 10 0x10 1:10
      add_cake_leaf "$WAN_IF" 1:10 10 "besteffort triple-isolate"

      # IoT class
      add_htb_class "$WAN_IF" 1:1 1:20 "$QOS_IOT_BW_UP" "$WAN_BW_UP" 1500 2
      add_fw_filter "$WAN_IF" 1: 20 0x20 1:20
      add_cake_leaf "$WAN_IF" 1:20 20 "besteffort"

      # Guest class
      add_htb_class "$WAN_IF" 1:1 1:30 "$QOS_GUEST_BW_UP" "$WAN_BW_UP" 1500 3
      add_fw_filter "$WAN_IF" 1: 30 0x30 1:30
      add_cake_leaf "$WAN_IF" 1:30 30 "besteffort"

      # Tailscale class
      if [ -d /sys/class/net/tailscale0 ]; then
        add_htb_class "$WAN_IF" 1:1 1:40 "$QOS_TAILSCALE_BW_UP" "$WAN_BW_UP" 1500 1
        add_fw_filter "$WAN_IF" 1: 40 0x40 1:40
        add_cake_leaf "$WAN_IF" 1:40 40 "besteffort triple-isolate"
      fi

      # Optional bridge-level shaping for wired LAN
      if [ -d /sys/class/net/br-lan ]; then
        add_qdisc_htb br-lan 2 10
        add_htb_class br-lan 2: 2:10 "$QOS_LAN_BW_UP" "$WAN_BW_UP" 1500 1
        add_cake_leaf br-lan 2:10 10 "besteffort"
      fi
      ;;
    stop)
      tc qdisc del dev "$WAN_IF" root 2>/dev/null || true
      [ -d /sys/class/net/br-lan ] && tc qdisc del dev br-lan root 2>/dev/null || true
      has_nft && nft delete table inet gl-qos 2>/dev/null || true
      log_info "Stopped WAN-rooted QoS on $WAN_IF"
      ;;
  esac
}

# ---------- SQM mode ----------
apply_sqm() {
  local action="$1"
  case "$action" in
    start|restart)
      stop >/dev/null 2>&1 || true
      [ "$WAN_BW_UP" -gt 0 ] || { log_err "WAN_BW_UP not set for SQM"; return 1; }
      log_info "Applying SQM CAKE diffserv on $WAN_IF at $WAN_BW_UP/$WAN_BW_DOWN kbit"
      detect_wan
      local bw="${WAN_BW_UP}kbit"
      tc qdisc add dev "$WAN_IF" root cake bandwidth "$bw" ethernet diffserv3 2>/dev/null || \
        tc qdisc change dev "$WAN_IF" root cake bandwidth "$bw" ethernet diffserv3 2>/dev/null || \
        log_err "Failed to apply SQM CAKE on $WAN_IF"
      ;;
    stop)
      tc qdisc del dev "$WAN_IF" root 2>/dev/null || true
      log_info "Stopped SQM on $WAN_IF"
      ;;
  esac
}

apply_qos() {
  local action="$1"
  case "$QOS_MODE" in
    sqm) apply_sqm "$action" ;;
    qos|*) apply_wan_rooted_qos "$action" ;;
  esac
}

# ---------- Status ----------
status() {
  echo "=== QoS Status ==="
  echo "Mode: $QOS_MODE"
  echo "Model: $MODEL"
  echo "WAN: $WAN_IF"
  echo "WAN_BW_UP: $WAN_BW_UP kbit"
  echo "WAN_BW_DOWN: $WAN_BW_DOWN kbit"
  echo "--- tc qdisc ---"
  tc qdisc show dev "$WAN_IF" 2>/dev/null || true
  [ -d /sys/class/net/br-lan ] && { echo "--- br-lan qdisc ---"; tc qdisc show dev br-lan 2>/dev/null || true; }
  echo "--- nft ---"
  has_nft && nft list table inet gl-qos 2>/dev/null || echo "nft not present"
}

# ---------- Install / uninstall ----------
install() {
  install -m 0755 "$MAIN_SCRIPT" /usr/local/sbin/glinet-vlan-qos.sh
  log_info "Installed $MAIN_SCRIPT to /usr/local/sbin/glinet-vlan-qos.sh"
}

uninstall() {
  stop >/dev/null 2>&1 || true
  rm -f /usr/local/sbin/glinet-vlan-qos.sh /usr/local/sbin/glinet-vlan-qos-setup.sh
  log_info "Uninstalled glinet-vlan-qos scripts"
}

# ---------- Main ----------
case "${1:-}" in
  start|restart)
    load_config
    detect_model
    [ "$MODEL" = "unknown" ] && log_err "Unknown model; run setup wizard or set QOS_MODEL"
    apply_qos start
    ;;
  stop)
    load_config
    apply_qos stop
    ;;
  status)
    load_config
    detect_model
    status
    ;;
  detect)
    detect_model
    ;;
  install)
    install
    ;;
  uninstall)
    uninstall
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|detect|install|uninstall}"
    exit 1
    ;;
esac
