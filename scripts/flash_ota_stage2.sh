#!/usr/bin/env bash
# Stage 2: flash logical partitions inside super via fastbootd, optionally wipe data.
# DEFAULT IS DRY-RUN. Pass --yes to actually flash.
#
# usage: flash_ota_stage2.sh --images DIR [--slot b] [--wipe] [--dry-run|--yes]
# Prereq: device is in fastbootd (`fastboot reboot fastboot`, `fastboot getvar is-userspace` -> yes)
set -uo pipefail
FA="${FASTBOOT:-fastboot}"
IMAGES=""; SLOT="b"; YES=0; WIPE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --images) IMAGES="${2:-}"; shift 2 ;;
    --slot) SLOT="${2:-}"; shift 2 ;;
    --wipe) WIPE=1; shift ;;
    --yes) YES=1; shift ;;
    --dry-run) YES=0; shift ;;
    -h|--help) echo "usage: $0 --images DIR [--slot b] [--wipe] [--dry-run|--yes]"; exit 0 ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done
[ -n "$IMAGES" ] && [ -d "$IMAGES" ] || { echo "!! --images 目录无效"; exit 2; }

PARTS="system vendor product odm system_ext system_dlkm vendor_dlkm"

if command -v "$FA" >/dev/null 2>&1; then
  userspace=$("$FA" getvar is-userspace 2>&1 | grep -m1 is-userspace || true)
  echo "$userspace"
  case "$userspace" in
    *yes*) ;;
    *) echo "!! 当前不是 fastbootd。先执行：fastboot reboot fastboot"; [ "$YES" -eq 1 ] && exit 1 ;;
  esac
fi

fail=0
for p in $PARTS; do
  src="$IMAGES/$p.img"
  [ -f "$src" ] || { echo "SKIP  $p (no image)"; continue; }
  dst="${p}_${SLOT}"
  size=$(stat -c %s "$src" 2>/dev/null || wc -c <"$src")
  if [ "$YES" -ne 1 ]; then
    echo "DRY   flash $dst  <- $(basename "$src") ($size bytes)"
    continue
  fi
  echo "=== $dst ($size bytes) ==="
  out=$("$FA" flash "$dst" "$src" 2>&1); rc=$?
  echo "$out" | tail -3
  if [ $rc -ne 0 ] || ! echo "$out" | grep -q "Finished"; then
    echo "FAILED $dst"; fail=1; break
  fi
done

if [ $fail -eq 0 ] && [ "$WIPE" -eq 1 ]; then
  if [ "$YES" -ne 1 ]; then
    echo "DRY   fastboot -w ; fastboot set_active $SLOT"
  else
    echo "=== wiping userdata ==="
    "$FA" -w 2>&1 | tail -5
    "$FA" set_active "$SLOT" 2>&1 | tail -2
    "$FA" reboot 2>&1 | tail -2
  fi
fi
echo "stage2 done fail=$fail"
exit $fail
