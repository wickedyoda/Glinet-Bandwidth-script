#!/bin/sh
#
# glinet-vlan-qos-setup.sh — Interactive setup for GL.iNet VLAN/SSID QoS
# Guides user through model selection, persistence, and VLAN priority ordering.
#
# Usage:
#   glinet-vlan-qos-setup.sh
#
# Repo: https://github.com/wickedyoda/Glinet-Bandwidth-script
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAIN_SCRIPT="/usr/local/sbin/glinet-vlan-qos.sh"
REPO_URL="https://github.com/wickedyoda/Glinet-Bandwidth-script"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $*"; }

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  log_err "This script must be run as root"
  exit 1
fi

# Check if main script exists
if [ ! -f "$MAIN_SCRIPT" ]; then
  log_err "Main script not found at $MAIN_SCRIPT"
  log_info "Please install glinet-vlan-qos.sh first"
  exit 1
fi

echo "========================================"
echo "  GL.iNet VLAN/SSID QoS Setup Wizard"
echo "========================================"
echo ""

# Step 1: Model Selection
log_step "Step 1: Select your GL.iNet model"
echo ""
echo "Supported models:"
echo "  1) GL.iNet Flint 3 (OpenWrt 23.05, tc-full, u32 filters supported)"
echo "  2) GL.iNet Flint 2 (OpenWrt 21.02, tc-tiny, no u32 filters)"
echo "  3) GL.iNet Flint 4 / GL-BE14000 (tc-tiny, no u32 filters)"
echo "  4) GL.iNet Slate 7 Pro / SlateMyBrain (OpenWrt 21.02, tc-tiny, no u32 filters)"
echo "  5) GL.iNet Slate 7 / slate-7-travel (OpenWrt 23.05, tc-full, u32 filters supported)"
echo "  6) GL.iNet Beryl 7 / GL-MT3600BE (OpenWrt 21.02, tc-tiny, no u32 filters)"
echo "  7) GL.iNet Flint 3e / GL-BE6500 (OpenWrt 23.05, tc-full, u32 filters supported)"
echo "  8) Auto-detect"
echo ""
read -p "Enter your choice [1-8, default: 8]: " model_choice
model_choice=${model_choice:-8}

case "$model_choice" in
  1)
    export QOS_MODEL=flint3
    MODEL_NAME="GL.iNet Flint 3"
    ;;
  2)
    export QOS_MODEL=flint2
    MODEL_NAME="GL.iNet Flint 2"
    ;;
  3)
    export QOS_MODEL=flint2
    MODEL_NAME="GL.iNet Flint 4 / GL-BE14000"
    ;;
  4)
    export QOS_MODEL=flint2
    MODEL_NAME="GL.iNet Slate 7 Pro / SlateMyBrain"
    ;;
  5)
    export QOS_MODEL=flint3
    MODEL_NAME="GL.iNet Slate 7 / slate-7-travel"
    ;;
  6)
    export QOS_MODEL=flint2
    MODEL_NAME="GL.iNet Beryl 7 / GL-MT3600BE"
    ;;
  7)
    export QOS_MODEL=flint3
    MODEL_NAME="GL.iNet Flint 3e / GL-BE6500"
    ;;
  8)
    log_info "Auto-detecting model..."
    DETECTED="$($MAIN_SCRIPT detect 2>/dev/null || echo "unknown")"
    if [ "$DETECTED" = "flint3" ]; then
      export QOS_MODEL=flint3
      MODEL_NAME="GL.iNet Flint 3 / Slate 7 / Flint 3e (auto-detected)"
    elif [ "$DETECTED" = "flint2" ]; then
      export QOS_MODEL=flint2
      MODEL_NAME="Flint 2-class device (auto-detected)"
    else
      log_warn "Could not auto-detect model, defaulting to Flint 2 (safe defaults)"
      export QOS_MODEL=flint2
      MODEL_NAME="Flint 2-class device (default)"
    fi
    ;;
  *)
    log_err "Invalid choice, defaulting to auto-detect"
    export QOS_MODEL=flint2
    MODEL_NAME="Flint 2-class device (default)"
    ;;
esac

log_info "Selected: $MODEL_NAME"
echo ""

# Step 2: Persistence Selection
log_step "Step 2: Choose persistence mode"
echo ""
echo "Persistence options:"
echo "  1) Persistent (recommended) - survives firmware upgrades and reboots"
echo "     Installs hooks in /etc/gl-switch.d/ and /etc/rc.local"
echo ""
echo "  2) Manual/Testing only - no auto-start hooks"
echo "     Survives UI changes but not reboots or firmware upgrades"
echo ""
read -p "Enter your choice [1-2, default: 1]: " persist_choice
persist_choice=${persist_choice:-1}

case "$persist_choice" in
  1)
    export PERSISTENT=1
    PERSIST_MODE="Persistent"
    ;;
  2)
    export PERSISTENT=0
    PERSIST_MODE="Manual/Testing"
    ;;
  *)
    log_warn "Invalid choice, defaulting to persistent"
    export PERSISTENT=1
    PERSIST_MODE="Persistent (default)"
    ;;
esac

log_info "Persistence: $PERSIST_MODE"
echo ""

# Step 3: VLAN/Bridge Priority Ordering
log_step "Step 3: Configure VLAN/SSID priority order"
echo ""
echo "Available network interfaces on your router:"
echo ""

# Detect available bridges
AVAILABLE_BRIDGES=""
for br in br-lan br-iot br-guest tailscale0; do
  if [ -d /sys/class/net/$br ]; then
    AVAILABLE_BRIDGES="$AVAILABLE_BRIDGES $br"
  fi
done

# Show available options with current SSID info
echo "Detected interfaces:"
i=1
for br in $AVAILABLE_BRIDGES; do
  case "$br" in
    br-lan)
      DESC="Main LAN + WiFi SSIDs (FREEPIZZA, MLO)"
      DEFAULT_PRIO=1
      ;;
    br-iot)
      DESC="IoT devices (Side_Salad_IOT)"
      DEFAULT_PRIO=2
      ;;
    br-guest)
      DESC="Guest network (Cheese_Sticks)"
      DEFAULT_PRIO=3
      ;;
    tailscale0)
      DESC="Tailscale mesh VPN"
      DEFAULT_PRIO=1
      ;;
    *)
      DESC="Unknown interface"
      DEFAULT_PRIO=3
      ;;
  esac
  echo "  $i) $br - $DESC"
  i=$((i+1))
done

echo ""
echo "Priority levels:"
echo "  1 = Highest priority (LAN/Admin/Tailscale)"
echo "  2 = Medium priority (IoT)"
echo "  3 = Lowest priority (Guest/Best-effort)"
echo ""

# Let user assign priorities
PRIORITY_CONFIG=""
for br in $AVAILABLE_BRIDGES; do
  case "$br" in
    br-lan) DEFAULT=1 ;;
    br-iot) DEFAULT=2 ;;
    br-guest) DEFAULT=3 ;;
    tailscale0) DEFAULT=1 ;;
    *) DEFAULT=3 ;;
  esac
  
  read -p "Set priority for $br [1-3, default: $DEFAULT]: " prio
  prio=${prio:-$DEFAULT}
  
  # Validate input
  if ! echo "$prio" | grep -qE '^[1-3]$'; then
    log_warn "Invalid priority '$prio', using default: $DEFAULT"
    prio=$DEFAULT
  fi
  
  PRIORITY_CONFIG="$PRIORITY_CONFIG $br=$prio"
done

echo ""
log_info "Priority configuration:"
for config in $PRIORITY_CONFIG; do
  br=$(echo "$config" | cut -d'=' -f1)
  prio=$(echo "$config" | cut -d'=' -f2)
  echo "  $br → Priority $prio"
done
echo ""

# Step 4: Apply Configuration
log_step "Step 4: Applying QoS configuration..."
echo ""

# Build config file
CONF_FILE="/etc/gl-qos-vlan.conf"
cat > "$CONF_FILE" <<EOF
# GL.iNet VLAN/SSID QoS Configuration
# Generated by glinet-vlan-qos-setup.sh on $(date)
# Model: $MODEL_NAME

# Model override (optional, auto-detected if not set)
# QOS_MODEL=$QOS_MODEL

# Persistence mode
PERSISTENT=$PERSISTENT

# Bandwidth limits (kbit/s)
QOS_LAN_BW_UP=200000
QOS_LAN_BW_DOWN=500000
QOS_IOT_BW_UP=50000
QOS_IOT_BW_DOWN=100000
QOS_GUEST_BW_UP=20000
QOS_GUEST_BW_DOWN=50000
QOS_TAILSCALE_BW_UP=50000
QOS_TAILSCALE_BW_DOWN=100000

# CAKE leaf qdisc
CAKE_ENABLE=1
EOF

log_info "Configuration saved to $CONF_FILE"
echo ""

# Apply QoS
log_info "Starting QoS..."
$MAIN_SCRIPT start 2>&1 || {
  log_err "Failed to start QoS"
  exit 1
}

# Install persistence if requested
if [ "$PERSISTENT" = "1" ]; then
  log_info "Installing persistence hooks..."
  $MAIN_SCRIPT install 2>&1 || log_warn "Persistence install had warnings"
else
  log_warn "Persistence disabled - QoS will not auto-start on reboot"
fi

echo ""

# Step 5: Verification
log_step "Step 5: Verifying configuration..."
echo ""

# Run status check
STATUS_OUTPUT=$($MAIN_SCRIPT status 2>&1)
echo "$STATUS_OUTPUT"
echo ""

# Verify key components
VERIFIED=1

# Check if HTB qdisc is active
if echo "$STATUS_OUTPUT" | grep -q "qdisc htb"; then
  log_info "✓ HTB qdisc is active"
else
  log_err "✗ HTB qdisc not found"
  VERIFIED=0
fi

# Check if nft table exists
if echo "$STATUS_OUTPUT" | grep -q "table inet gl-qos"; then
  log_info "✓ nft marks configured"
else
  log_warn "⚠ nft marks not found (may use iptables instead)"
fi

# Check model detection
DETECTED_MODEL=$($MAIN_SCRIPT detect 2>/dev/null || echo "unknown")
log_info "Detected model: $DETECTED_MODEL"

echo ""
if [ $VERIFIED -eq 1 ]; then
  log_info "Verification passed ✓"
else
  log_warn "Verification completed with warnings"
fi

# Step 6: Summary
echo ""
echo "========================================"
echo "  Setup Complete!"
echo "========================================"
echo ""
log_info "Model: $MODEL_NAME"
log_info "Persistence: $PERSIST_MODE"
log_info "Priority order:"
for config in $PRIORITY_CONFIG; do
  br=$(echo "$config" | cut -d'=' -f1)
  prio=$(echo "$config" | cut -d'=' -f2)
  echo "  - $br: Priority $prio"
done
echo ""
log_info "Configuration file: $CONF_FILE"
log_info "Main script: $MAIN_SCRIPT"
echo ""
echo "Useful commands:"
echo "  $MAIN_SCRIPT status   - Check QoS status"
echo "  $MAIN_SCRIPT restart  - Restart QoS"
echo "  $MAIN_SCRIPT stop     - Stop QoS"
echo "  $MAIN_SCRIPT detect   - Detect router model"
echo ""
echo -e "${GREEN}Thank you for using GL.iNet VLAN/SSID QoS!${NC}"
echo ""
echo "Repository: $REPO_URL"
echo "Issues/Questions: $REPO_URL/issues"
echo ""
exit 0
