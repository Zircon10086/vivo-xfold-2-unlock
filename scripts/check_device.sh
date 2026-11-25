#!/usr/bin/env bash
# Read-only device check for PD2266. No writes, no root required (uses su only for devinfo read).
set -uo pipefail
ADB="${ADB:-adb}"

say() { printf '%s\n' "$*"; }
get() { "$ADB" shell "$1" 2>/dev/null | tr -d '\r'; }

say "== adb =="
"$ADB" devices | sed -n '2,$p'

dev=$(get 'getprop ro.product.device')
model=$(get 'getprop ro.product.model')
build=$(get 'getprop ro.build.display.id')
slot=$(get 'getprop ro.boot.slot_suffix')
locked=$(get 'getprop ro.boot.flash.locked')
vbs=$(get 'getprop ro.boot.verifiedbootstate')
vbm=$(get 'getprop ro.boot.vbmeta.device_state')

say ""
say "device : ${dev:-?} / ${model:-?}"
say "build  : ${build:-?}"
say "slot   : ${slot:-?}"
say "locked : ${locked:-?}"
say "vbs    : ${vbs:-?} (orange = unlocked)"
say "vbmeta : ${vbm:-?}"

say ""
level=$(get 'dumpsys battery | grep -m1 "level:"')
say "battery: ${level:-?}"

if [ "$dev" != "PD2266" ]; then
  say ""
  say "!! 该机型不是 PD2266。本项目的 devinfo 偏移与分区表只保证在 PD2266 上有效。"
fi

say ""
say "== fastboot =="
FB="${FASTBOOT:-fastboot}"
if command -v "$FB" >/dev/null 2>&1; then
  "$FB" devices 2>/dev/null | head -5
else
  say "$FB 不在 PATH（可设置 FASTBOOT=/path/to/fastboot）"
fi
say ""
say "注意：ro.boot.flash.locked / verifiedbootstate 可能被 PlayIntegrityFix、"
say "Tricky Store 等模块伪造（resetprop）。以 bootloader 里的"
say "'fastboot getvar unlocked' 为准。"

say ""
say "== devinfo（需要 root） =="
tmp=/data/local/tmp/devinfo_check.bin
if "$ADB" shell su -c "dd if=/dev/block/by-name/devinfo of=$tmp bs=4096 count=1 2>/dev/null" >/dev/null 2>&1; then
  "$ADB" shell "od -An -tx1 -j0 -N16 $tmp; echo; od -An -tx1 -j13 -N2 $tmp; echo" 2>/dev/null | tr -d '\r'
  say "（最后一行两个字节依次是 0x0d unlocked / 0x0e critical，00 00 表示未解锁）"
  "$ADB" shell "rm -f $tmp" >/dev/null 2>&1
else
  say "无法读取 devinfo（没有 root 或 dd 被拦）——解锁步骤需要临时 root。"
fi
