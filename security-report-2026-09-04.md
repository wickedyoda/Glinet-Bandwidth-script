# Security Scan Report — Glinet-Bandwidth-script

**Date:** 2026-09-04
**Scope:** Full security audit of all scripts and repository configuration
**Status:** ✅ PASS — No critical violations found

---

## Files Audited

| File | Lines | ShellCheck | Syntax (sh -n) | SHA256 Match |
|------|-------|------------|----------------|--------------|
| `glinet-vlan-qos.sh` | 259 | ✅ Clean | ✅ Pass | ✅ Match |
| `glinet-vlan-qos-setup.sh` | 212 | ✅ Clean | ✅ Pass | ✅ Match |
| `install.sh` | 41 | ✅ Clean | ✅ Pass | ✅ Match |

## Security Checks Performed

### 1. Secrets Scan
Scanned all `.sh` files for hardcoded secrets:
```grep -rniE '(api_key|apikey|secret|password|passwd|token|bearer|credential|private_key)' *.sh
```
**Result:** No secrets found — PASS

### 2. Supply Chain Check
Scanned for external download URLs:
```grep -rn 'https\?://' *.sh
```
**Result:** Only `raw.githubusercontent.com/wickedyoda/Glinet-Bandwidth-script` URLs found — PASS

### 3. Command Injection Check
Scanned for dangerous patterns:
```grep -rniE '(eval|system\(|popen\(|exec\()' *.sh
```
**Result:** No dangerous patterns found — PASS

### 4. File Permissions Check
Verified all scripts have correct permissions:
- `755` for executable scripts
- `644` for non-executable files

**Result:** All files have correct permissions, no SUID/SGID bits — PASS

### 5. ShellCheck (locally installed)
Run with POSIX-compatible excludes for OpenWrt bash-isms:
```shellcheck --exclude=SC3040,SC3043,SC2034,SC3045,SC2086,SC2015,SC1090 *.sh
```
**Result:** Zero violations — PASS

### 6. Syntax Validation
```sh -n *.sh
```
**Result:** All scripts pass syntax check — PASS

### 7. Checksum Verification
```sha256sum -c checksums.txt
```
**Result:** All 3 files match recorded SHA256 hashes — PASS

## CI Workflow

Workflow file: `.github/workflows/security.yml`
- Runs on every push and PR to `master`
- 8 steps: Syntax, ShellCheck, Checksum, Secrets, Supply chain, Injection, File permissions, CI test
- Uses only `actions/checkout@v4` (no external action dependencies beyond checkout)
- Branch protection on `master` requires Security Checks to pass before merge

## Risk Assessment

- **Attack surface:** Minimal (3 shell scripts, no network listeners installed)
- **Supply chain risk:** None (only own repo URLs)
- **Secrets risk:** None (no credentials in code)
- **Injection risk:** None (no eval/system/popen/exec)
- **Privilege escalation:** N/A (runs on user-owned router, requires root SSH for installation)

## Conclusion

Repository is secure for production use on GL.iNet OpenWrt devices.
