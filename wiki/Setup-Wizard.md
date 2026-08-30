# Setup Wizard

Run `/usr/local/sbin/glinet-vlan-qos-setup.sh` on the router.

The wizard is interactive and guides you through six steps.

## Step 0: Select traffic shaping mode

Choose the overall shaping behavior:

- **QoS** — per-VLAN/SSID priority with HTB + CAKE
- **SQM** — Smart Queue Management with CAKE for overall WAN shaping

This choice is stored in `/etc/gl-qos-vlan.conf` and used by `glinet-vlan-qos.sh`.

## Step 1: Select your GL.iNet model

Choose from:

1. GL.iNet Flint 3
2. GL.iNet Flint 2
3. GL.iNet Flint 4 / GL-BE14000
4. GL.iNet Slate 7 Pro / SlateMyBrain
5. GL.iNet Slate 7 / slate-7-travel
6. GL.iNet Beryl 7 / GL-MT3600BE
7. GL.iNet Flint 3e / GL-BE6500
8. Auto-detect

Auto-detect reads `/etc/board.json` and selects the matching code path. If it cannot match your device, it warns you and asks for confirmation before continuing with Flint 2-safe defaults.

## Step 2: Choose persistence mode

- **Persistent** — survives reboots and firmware upgrades
- **Manual/Testing** — no auto-start hooks; useful for testing

## Step 3: Configure VLAN/SSID priority order

The wizard lists detected interfaces and asks you to assign a priority to each:

- `1` — Highest priority
- `2` — Medium priority
- `3` — Lowest priority

Only interfaces that actually exist on the router are shown.

## Step 4: Apply configuration

The wizard writes `/etc/gl-qos-vlan.conf`, runs the main script, and installs persistence hooks if requested.

## Step 5: Verification

After apply, the wizard checks:

- HTB qdiscs on each bridge
- nft marks in table `inet gl-qos`
- Model detection output

If verification fails, review the output before relying on the configuration.

## Step 6: Summary

The wizard prints a summary including:

- Selected model
- Mode
- Persistence choice
- Priority order
- Config and script paths
- Useful follow-up commands
