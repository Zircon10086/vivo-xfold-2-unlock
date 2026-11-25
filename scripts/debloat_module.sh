#!/usr/bin/env bash
# Build a KernelSU module that re-applies a disable list on every boot,
# then install it with `ksud module install`.
# DEFAULT IS DRY-RUN (build only). Pass --install to push and install.
#
# usage: debloat_module.sh --packages packages.tsv [--id pd2266_debloat]
#                          [--name "PD2266 Debloat"] [--dry-run|--install]
# TSV format: <package><TAB>disable|uninstall   (lines starting with # ignored)
set -uo pipefail
ADB="${ADB:-adb}"
PKGS=""; MID="pd2266_debloat"; MNAME="PD2266 Debloat"; INSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --packages) PKGS="${2:-}"; shift 2 ;;
    --id) MID="${2:-}"; shift 2 ;;
    --name) MNAME="${2:-}"; shift 2 ;;
    --install) INSTALL=1; shift ;;
    --dry-run) INSTALL=0; shift ;;
    -h|--help) echo "usage: $0 --packages FILE [--id id] [--name name] [--dry-run|--install]"; exit 0 ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done
[ -f "$PKGS" ] || { echo "!! --packages 文件不存在"; exit 2; }

WORK="$(mktemp -d)"; MOD="$WORK/$MID"
mkdir -p "$MOD"
LIST=""
while IFS=$'\t' read -r pkg action; do
  case "$pkg" in ''|'#'*) continue ;; esac
  case "$action" in
    disable|uninstall) LIST="$LIST$pkg $action"$'\n' ;;
    '') LIST="$LIST$pkg disable"$'\n' ;;
    *) echo "跳过未知动作：$pkg $action";;
  esac
done < "$PKGS"

if [ -z "$LIST" ]; then echo "!! 清单为空"; exit 2; fi

cat > "$MOD/module.prop" <<EOF
id=$MID
name=$MNAME
version=v1.0
versionCode=1
author=local
description=Re-apply debloat/telemetry disable list on every boot (reversible with pm enable).
EOF

{
  echo '#!/system/bin/sh'
  echo 'MODDIR=${0%/*}'
  echo 'LOG=/data/local/tmp/'"$MID"'.log'
  echo 'until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done'
  echo 'sleep 20'
  echo '{'
  echo '  echo "=== $(date) '"$MID"' ==="'
  echo "$LIST" | while read -r pkg action; do
    [ -n "$pkg" ] || continue
    if [ "$action" = "uninstall" ]; then
      echo "  pm uninstall --user 0 $pkg >> \"\$LOG\" 2>&1"
    else
      echo "  pm disable-user --user 0 $pkg >> \"\$LOG\" 2>&1"
    fi
  done
  echo '  echo done'
  echo '} >> "$LOG" 2>&1'
} > "$MOD/service.sh"
chmod 755 "$MOD/service.sh"

ZIP="$WORK/$MID.zip"
if command -v zip >/dev/null 2>&1; then
  (cd "$MOD" && zip -qr "$ZIP" .)
elif command -v 7z >/dev/null 2>&1; then
  (cd "$MOD" && 7z a -tzip -mx=9 "$ZIP" . >/dev/null)
else
  echo "!! 需要 zip 或 7z 来打包"; exit 1
fi

echo "生成模块：$ZIP"
echo "包含 $(echo "$LIST" | grep -c .) 个包："
echo "$LIST" | sed 's/^/  /'

if [ "$INSTALL" -ne 1 ]; then
  echo "DRY-RUN：加 --install 会执行 adb push + ksud module install"
  echo "模块目录保留在：$MOD"
  exit 0
fi

"$ADB" push "$ZIP" /data/local/tmp/module.zip >/dev/null || exit 1
out=$("$ADB" shell "su -c '/data/adb/ksud module install /data/local/tmp/module.zip'" 2>&1)
echo "$out" | tail -5
echo "$out" | grep -q "successfully" || { echo "!! 安装失败（注意 /data/adb/modules 不能直接写，必须走 ksud）"; exit 1; }
echo "安装完成。重启后生效；也可立刻运行：adb shell su -c 'sh /data/adb/modules/$MID/service.sh &'"
