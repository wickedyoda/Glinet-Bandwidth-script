#!/bin/sh
# glinet-vlan-qos-setup.sh - Interactive setup wizard for GL.iNet bandwidth QoS
# GPLv3 - see LICENSE

set -euo pipefail

MAIN_SCRIPT="/usr/local/sbin/glinet-vlan-qos.sh"
CONF_FILE="/etc/gl-qos-vlan.conf"

log_info() { echo "INFO: $*"; }
log_warn() { echo "WARN: $*"; }
log_err() { echo "ERR: $*" >&2; }

# ---------- Model detection ----------
detect_model() {
  local board
  board=$(cat /etc/board.json 2>/dev/null || echo '{}')
  case "$board" in
    *'"glinet,gl-be14000"'*|*'"glinet,gl-mt6000"'*|*'"glinet,gl-be10000"'*|*'"glinet,gl-mt3600be"'*) echo "flint2" ;;
    *'"qcom,ipq5332-ap-mi01.6"'*|*'"glinet,gl-be3600"'*|*'"qcom,ipq5332-ap-mi04.1-v1"'*) echo "flint3" ;;
    *) echo "unknown" ;;
  esac
}

# ---------- Step 0: Mode selection ----------
select_mode() {
  echo ""
  echo "=== Step 0: Traffic Shaping Mode ==="
  echo "1) QoS (HTB + CAKE) - WAN-rooted per-VLAN priority"
  echo "2) SQM (CAKE diffserv) - Smart Queue Management on WAN only"
  read -p "Select mode [1-2]: " -r mode
  case "$mode" in
    2) QOS_MODE="sqm" ;;
    1|*) QOS_MODE="qos" ;;
  esac
  echo "QOS_MODE=$QOS_MODE"
}

# ---------- Step 1: Model selection ----------
select_model() {
  echo ""
  echo "=== Step 1: Router Model ==="
  echo "1) GL.iNet Flint 2 (GL-MT6000)"
  echo "2) GL.iNet Flint 3 (GL-BE9300)"
  echo "3) GL.iNet Flint 4 (GL-BE14000)"
  echo "4) GL.iNet Slate 7 (GL-BE3600)"
  echo "5) GL.iNet Slate 7 Pro (GL-BE10000)"
  echo "6) GL.iNet Beryl 7 (GL-MT3600BE)"
  echo "7) GL.iNet Flint 3e (GL-BE6500)"
  echo "8) Auto-detect"
  read -p "Select model [1-8]: " -r m
  case "$m" in
    1) QOS_MODEL="flint2" ;;
    2) QOS_MODEL="flint3" ;;
    3) QOS_MODEL="flint4" ;;
    4) QOS_MODEL="slate7" ;;
    5) QOS_MODEL="slate7pro" ;;
    6) QOS_MODEL="beryl7" ;;
    7) QOS_MODEL="flint3e" ;;
    8|*)
      detected=$(detect_model)
      if [ "$detected" = "unknown" ]; then
        echo "WARN: Could not auto-detect model. Continuing with Flint 2 defaults."
        echo "This is not recommended. If issues occur, please select your model manually."
        read -p "Continue anyway? [y/N]: " -r confirm
        case "$confirm" in
          y|Y|yes) : ;;
          *) log_err "Aborted"; exit 1 ;;
        esac
        detected="flint2"
      fi
      QOS_MODEL="$detected"
      ;;
  esac
  echo "QOS_MODEL=$QOS_MODEL"
}

# ---------- Step 2: Persistence ----------
select_persistence() {
  echo ""
  echo "=== Step 2: Persistence ==="
  echo "1) Enable (survives reboot and firmware upgrade)"
  echo "2) Disable (manual only)"
  read -p "Select [1-2]: " -r p
  case "$p" in
    1) PERSISTENT=1 ;;
    2|*) PERSISTENT=0 ;;
  esac
  echo "PERSISTENT=$PERSISTENT"
}

# ---------- Dynamic bridge discovery ----------
# Discover all bridge interfaces and map them to VLAN classes.
discover_bridges() {
  local idx=0
  local br
  for br in /sys/class/net/br-*; do
    [ -d "$br" ] || continue
    br=$(basename "$br")
    idx=$((idx + 1))
    local mark=$((16 + (idx - 1) * 16))  # 0x10, 0x20, 0x30, ...
    echo "${br} ${mark}"
  done
  # Add tailscale0 if present
  if [ -d /sys/class/net/tailscale0 ]; then
    idx=$((idx + 1))
    local mark=$((16 + (idx - 1) * 16))
    echo "tailscale0 ${mark}"
  fi
}

# ---------- Step 3: Bridge Priority ----------
select_priority() {
  echo ""
  echo "=== Step 3: Bridge Priority ==="
  echo "Assign priority 1 (highest) to 3 (lowest) for traffic on each bridge:"

  # Dynamically discover all bridges + tailscale0
  local discovered=""
  for br in /sys/class/net/br-*; do
    [ -d "$br" ] || continue
    br=$(basename "$br")
    discovered="$discovered $br"
  done
  # Add tailscale0 if present
  [ -d /sys/class/net/tailscale0 ] && discovered="$discovered tailscale0"

  for b in $discovered; do
    read -p "Priority for $b (1-3, 0 to skip): " -r pri
    local config_name
    # Convert bridge name to config variable suffix (e.g., br-lan -> LAN)
    case "$b" in
      br-lan|lan) config_name="LAN" ;;
      br-iot|iot) config_name="IOT" ;;
      br-guest|guest) config_name="GUEST" ;;
      tailscale0|tailscale) config_name="TAILSCALE" ;;
      br-*) config_name=$(echo "$b" | sed 's/br-//' | tr '[:lower:]' '[:upper:]') ;;
      *) config_name=$(echo "$b" | tr '[:lower:]' '[:upper:]') ;;
    esac

    case "$pri" in
      1|2|3)
        case "$config_name" in
          LAN) PRIOR_LAN=$pri ;;
          IOT) PRIOR_IOT=$pri ;;
          GUEST) PRIOR_GUEST=$pri ;;
          TAILSCALE) PRIOR_TAILSCALE=$pri ;;
          *) eval "PRIOR_${config_name}=${pri}" ;;
        esac
        # Also set the bandwidth priority variable for this bridge
        eval "QOS_PRIO_${config_name}=\${pri}"
        ;;
      *)
        case "$config_name" in
          LAN) PRIOR_LAN=skip ;;
          IOT) PRIOR_IOT=skip ;;
          GUEST) PRIOR_GUEST=skip ;;
          TAILSCALE) PRIOR_TAILSCALE=skip ;;
          *) eval "PRIOR_${config_name}=skip" ;;
        esac
        ;;
    esac
  done
}

# ---------- Step 4: WAN Bandwidth ----------
select_bandwidth() {
  echo ""
  echo "=== Step 4: WAN Bandwidth ==="
  read -p "WAN upload limit (kbps, e.g. 100000 for 100Mbps): " -r up
  read -p "WAN download limit (kbps, e.g. 500000 for 500Mbps): " -r down
  WAN_BW_UP="${up:-100000}"
  WAN_BW_DOWN="${down:-500000}"
  echo "WAN_BW_UP=$WAN_BW_UP"
  echo "WAN_BW_DOWN=$WAN_BW_DOWN"
}

# ---------- Write config ----------
write_config() {
  {
    echo "# Generated by glinet-vlan-qos-setup.sh"
    echo "QOS_MODE=$QOS_MODE"
    echo "QOS_MODEL=$QOS_MODEL"
    echo "PERSISTENT=$PERSISTENT"
    echo "WAN_BW_UP=$WAN_BW_UP"
    echo "WAN_BW_DOWN=$WAN_BW_DOWN"

    # Generate bandwidth config for each discovered bridge
    for br in /sys/class/net/br-*; do
      [ -d "$br" ] || continue
      br=$(basename "$br")
      local config_name up_bw down_bw prio
      case "$br" in
        br-lan|lan) config_name="LAN" ;;
        br-iot|iot) config_name="IOT" ;;
        br-guest|guest) config_name="GUEST" ;;
        tailscale0|tailscale) config_name="TAILSCALE" ;;
        br-*) config_name=$(echo "$br" | sed 's/br-//' | tr '[:lower:]' '[:upper:]') ;;
        *) config_name=$(echo "$br" | tr '[:lower:]' '[:upper:]') ;;
      esac

      # Use stored bandwidth if available, otherwise default
      eval "up_bw=\${QOS_${config_name}_BW_UP:-}"
      eval "down_bw=\${QOS_${config_name}_BW_DOWN:-}"
      eval "prio=\${PRIOR_${config_name}:-}"

      # If not set, use defaults based on bridge type
      [ -z "$up_bw" ] && {
        case "$config_name" in
          LAN) up_bw=200; down_bw=500 ;;
          IOT) up_bw=100; down_bw=200 ;;
          GUEST) up_bw=100; down_bw=200 ;;
          TAILSCALE) up_bw=200; down_bw=500 ;;
          *) up_bw=200; down_bw=500 ;;
        esac
      }

      # Default priority: 1 for LAN/Tailscale, 2 for IoT, 3 for Guest/others
      [ -z "$prio" ] || [ "$prio" = "skip" ] && {
        case "$config_name" in
          LAN|TAILSCALE) prio=1 ;;
          IOT) prio=2 ;;
          *) prio=3 ;;
        esac
      }

      echo "QOS_${config_name}_BW_UP=${up_bw}000"
      echo "QOS_${config_name}_BW_DOWN=${down_bw}000"
      echo "QOS_PRIO_${config_name}=$prio"
    done

    # Add tailscale0 config if present
    if [ -d /sys/class/net/tailscale0 ]; then
      config_name="TAILSCALE"
      eval "up_bw=\${QOS_TAILSCALE_BW_UP:-}"
      eval "down_bw=\${QOS_TAILSCALE_BW_DOWN:-}"
      eval "prio=\${PRIOR_TAILSCALE:-}"
      [ -z "$up_bw" ] && up_bw=200
      [ -z "$down_bw" ] && down_bw=500
      [ -z "$prio" ] && prio=1
      echo "QOS_TAILSCALE_BW_UP=${up_bw}000"
      echo "QOS_TAILSCALE_BW_DOWN=${down_bw}000"
      echo "QOS_PRIO_TAILSCALE=$prio"
    fi

    echo "CAKE_ENABLE=1"
  } > "$CONF_FILE"
  echo "Wrote $CONF_FILE"
}

# ---------- Setup persistence ----------
setup_persistence() {
  [ "$PERSISTENT" != "1" ] && return 0
  log_info "Setting up persistence..."

  # rc.local
  if [ -f /etc/rc.local ]; then
    grep -q "glinet-vlan-qos.sh start" /etc/rc.local 2>/dev/null || {
      sed -i '/^exit 0$/d' /etc/rc.local 2>/dev/null || true
      printf '\n# VLAN QoS persistence\nif [ -x /usr/local/sbin/glinet-vlan-qos.sh ]; then\n  /usr/local/sbin/glinet-vlan-qos.sh start >/dev/null 2>&1 || true\nfi\n' >> /etc/rc.local
      log_info "Added to rc.local"
    }
  fi

  # sysupgrade protection
  mkdir -p /etc/sysupgrade.conf.d
  printf '/usr/local/sbin/glinet-vlan-qos.sh\n/etc/gl-qos-vlan.conf\n' > /etc/sysupgrade.conf.d/glinet-qos.conf
  log_info "Added to sysupgrade protection"

  # gl-switch.d hook
  mkdir -p /etc/gl-switch.d
  cat > /etc/gl-switch.d/vlan-qos.sh <<'HOOK'
#!/bin/sh
case "$1" in
  on|off|start) /usr/local/sbin/glinet-vlan-qos.sh start >/dev/null 2>&1 || true ;;
esac
HOOK
  chmod +x /etc/gl-switch.d/vlan-qos.sh
  log_info "Added to gl-switch.d"
}

# ---------- Main ----------
QOS_MODE="qos"
QOS_MODEL=""
PERSISTENT=0
WAN_BW_UP=0
WAN_BW_DOWN=0

main() {
  if [ "${1:-}" = "uninstall" ]; then
    if [ -x "$MAIN_SCRIPT" ]; then
      exec "$MAIN_SCRIPT" uninstall
    fi
    log_err "$MAIN_SCRIPT is not installed"
    exit 1
  fi

  echo "GL.iNet Bandwidth QoS Setup Wizard"
  echo "===================================="

  select_mode
  select_model
  select_persistence
  select_priority
  select_bandwidth

  echo ""
  echo "=== Summary ==="
  echo "Mode: $QOS_MODE"
  echo "Model: $QOS_MODEL"
  echo "Persistent: $PERSISTENT"
  echo "WAN: ${WAN_BW_UP} up / ${WAN_BW_DOWN} down kbps"

  read -p "Write config and apply? [y/N]: " -r confirm
  case "$confirm" in
    y|Y|yes)
      write_config
      setup_persistence
      echo "Run '$MAIN_SCRIPT start' to apply"
      ;;
    *)
      log_info "Cancelled"
      exit 0
      ;;
  esac
}

main "$@"
