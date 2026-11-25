#!/usr/bin/env bash
# Stage 1: flash firmware + boot chain to one slot via bootloader fastboot.
# DEFAULT IS DRY-RUN. Pass --yes to actually flash.
#
# usage: flash_ota_stage1.sh --images DIR [--slot b] [--dry-run|--yes]
set -uo pipefail
FA="${FASTBOOT:-fastboot}"
IMAGES=""; SLOT="b"; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --images) IMAGES="${2:-}"; shift 2 ;;
    --slot) SLOT="${2:-}"; shift 2 ;;
    --yes) YES=1; shift ;;
    --dry-run) YES=0; shift ;;
    -h|--help) echo "usage: $0 --images DIR [--slot b] [--dry-run|--yes]"; exit 0 ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done
[ -n "$IMAGES" ] && [ -d "$IMAGES" ] || { echo "!! --images 目录无效"; exit 2; }

PARTS="xbl xbl_config xbl_ramdump abl aop aop_config tz hyp devcfg keymaster qupfw \
uefi uefisecapp shrm cpucp featenabler imagefv multiimgoem multiimgqti storage \
bluetooth modem dsp vm-bootsys boot init_boot vendor_boot dtbo recovery vbmeta vbmeta_system"

echo "slot=$SLOT images=$IMAGES dry-run=$([ $YES -eq 1 ] && echo no || echo yes)"
if [ "$YES" -eq 1 ]; then
  "$FA" getvar current-slot 2>&1 | grep -m1 current-slot || true
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
echo "stage1 done fail=$fail"
exit $fail
