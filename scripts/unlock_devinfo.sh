#!/usr/bin/env bash
# Write devinfo unlock flags (0x0d = unlocked, 0x0e = critical) on PD2266.
# DEFAULT IS DRY-RUN. Pass --yes to actually write. Requires temporary root.
set -uo pipefail
ADB="${ADB:-adb}"
YES=0
for a in "$@"; do
  case "$a" in
    --yes) YES=1 ;;
    --dry-run) YES=0 ;;
    -h|--help) echo "usage: $0 [--dry-run|--yes]"; exit 0 ;;
    *) echo "unknown arg: $a"; exit 2 ;;
  esac
done

get() { "$ADB" shell "$1" 2>/dev/null | tr -d '\r'; }
dev=$(get 'getprop ro.product.device')
build=$(get 'getprop ro.build.display.id')
echo "device=$dev build=$build"

if [ "$dev" != "PD2266" ]; then
  echo "!! 拒绝执行：本脚本只针对 PD2266（当前 ${dev:-未知}）。"
  exit 1
fi

if ! "$ADB" shell su -c id >/dev/null 2>&1; then
  echo "!! 没有 root（su 不可用），无法写 devinfo。请先取得临时 root。"
  exit 1
fi

tmpb=/data/local/tmp/devinfo.before
if ! "$ADB" shell su -c "dd if=/dev/block/by-name/devinfo of=$tmpb bs=4096 count=1 2>/dev/null" >/dev/null 2>&1; then
  echo "!! 读取 devinfo 失败"; exit 1
fi

magic=$("$ADB" shell "dd if=$tmpb bs=1 count=13 2>/dev/null" 2>/dev/null | tr -d '\r')
flags=$("$ADB" shell "od -An -tx1 -j13 -N2 $tmpb" 2>/dev/null | tr -d '\r' | tr -s ' ')
echo "magic=$magic"
echo "0x0d/0x0e =$flags"

case "$magic" in
  ANDROID-BOOT!) ;;
  *) echo "!! devinfo magic 不是 ANDROID-BOOT!，停止（不要写入未知布局）"; exit 1 ;;
esac

if [ "$flags" = " 01 01" ] || [ "$flags" = "01 01" ]; then
  echo "已经是解锁状态，无需写入。"
  exit 0
fi

echo "将写入：devinfo 偏移 0x0d=0x01、0x0e=0x01（其余字节保持不变）"
if [ "$YES" -ne 1 ]; then
  echo "DRY-RUN：加 --yes 才会真正写入。写入前请确认 recovery 里有「清除所有数据」。"
  exit 0
fi

echo "备份原始 devinfo 到当前目录：devinfo.$(date +%Y%m%d-%H%M%S).img"
"$ADB" pull "$tmpb" "devinfo.$(date +%Y%m%d-%H%M%S).img" >/dev/null 2>&1 || true

echo "写入中..."
"$ADB" shell su -c "printf '\\001' | dd of=/dev/block/by-name/devinfo bs=1 seek=13 conv=notrunc 2>/dev/null" || { echo "!! 写 0x0d 失败"; exit 1; }
"$ADB" shell su -c "printf '\\001' | dd of=/dev/block/by-name/devinfo bs=1 seek=14 conv=notrunc 2>/dev/null" || { echo "!! 写 0x0e 失败"; exit 1; }
"$ADB" shell su -c "sync"

tmpa=/data/local/tmp/devinfo.after
"$ADB" shell su -c "dd if=/dev/block/by-name/devinfo of=$tmpa bs=4096 count=1 2>/dev/null"
echo "回读："
"$ADB" shell "od -An -tx1 -j13 -N2 $tmpa" | tr -d '\r'
echo ""
echo "完成。现在重启：adb reboot"
echo "开机出现 device is corrupt 时，进 recovery 选「清除数据 → 清除所有数据」，不要选修复系统。"
"$ADB" shell "rm -f $tmpb $tmpa" >/dev/null 2>&1
