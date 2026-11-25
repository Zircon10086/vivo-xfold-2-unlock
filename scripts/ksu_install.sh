#!/usr/bin/env bash
# Patch a stock init_boot.img with KernelSU/ReSukiSU LKM and flash it.
# DEFAULT IS DRY-RUN. Pass --yes to flash.
#
# usage: ksu_install.sh --init-boot init_boot.img [--ksud /path/to/ksud]
#                       [--kmi android13-5.15] [--slot b] [--manager app.apk]
#                       [--allow-shell] [--dry-run|--yes]
set -uo pipefail
ADB="${ADB:-adb}"; FA="${FASTBOOT:-fastboot}"
INIT=""; KSUD=""; KMI="android13-5.15"; SLOT="b"; MANAGER=""; ALLOW=0; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --init-boot) INIT="${2:-}"; shift 2 ;;
    --ksud) KSUD="${2:-}"; shift 2 ;;
    --kmi) KMI="${2:-}"; shift 2 ;;
    --slot) SLOT="${2:-}"; shift 2 ;;
    --manager) MANAGER="${2:-}"; shift 2 ;;
    --allow-shell) ALLOW=1; shift ;;
    --yes) YES=1; shift ;;
    --dry-run) YES=0; shift ;;
    -h|--help) echo "usage: $0 --init-boot FILE [--ksud FILE] [--kmi ...] [--slot b] [--manager APK] [--allow-shell] [--dry-run|--yes]"; exit 0 ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done
[ -f "$INIT" ] || { echo "!! --init-boot 不存在"; exit 2; }

DKS=/data/local/tmp/ksud
if [ -n "$KSUD" ]; then
  [ -f "$KSUD" ] || { echo "!! --ksud 不存在"; exit 2; }
  "$ADB" push "$KSUD" "$DKS" >/dev/null || exit 1
fi
"$ADB" shell "chmod 755 $DKS" >/dev/null 2>&1 || true

"$ADB" push "$INIT" /sdcard/Download/init_boot_stock.img >/dev/null || exit 1
OPTS="--kmi $KMI --partition init_boot --out-name ksu_patched.img -o /sdcard/Download"
[ "$ALLOW" -eq 1 ] && OPTS="$OPTS --allow-shell"

echo "boot-patch: $DKS boot-patch -b /sdcard/Download/init_boot_stock.img $OPTS"
out=$("$ADB" shell "$DKS boot-patch -b /sdcard/Download/init_boot_stock.img $OPTS" 2>&1)
echo "$out" | tail -8
echo "$out" | grep -q "Done" || { echo "!! boot-patch 失败"; exit 1; }

"$ADB" pull /sdcard/Download/ksu_patched.img ./ksu_patched.img >/dev/null || exit 1
echo "已生成 ./ksu_patched.img"

if [ "$YES" -ne 1 ]; then
  echo "DRY-RUN：将执行 fastboot flash init_boot_${SLOT} ksu_patched.img（加 --yes 真正执行）"
  exit 0
fi

"$ADB" reboot bootloader
sleep 8
"$FA" flash "init_boot_${SLOT}" ./ksu_patched.img || { echo "!! 刷写失败"; exit 1; }
"$FA" reboot

if [ -n "$MANAGER" ] && [ -f "$MANAGER" ]; then
  echo "等待开机后安装管理器..."
  "$ADB" wait-for-device
  "$ADB" shell "sleep 20" >/dev/null 2>&1 || true
  "$ADB" install -r "$MANAGER" || true
fi
echo "完成后可用：adb shell su -c id"
