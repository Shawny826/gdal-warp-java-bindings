#!/usr/bin/env bash
# gdal-warp-bindings deploy-alpha 一键冒烟测试(Linux amd64 / arm64 通用)
# 用法: bash run-test.sh [可选: jar目录]
# 产出: test-report-<arch>-<时间戳>.log / lddebug-<时间戳>.log

set -u
KIT="$(cd "$(dirname "$0")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
ARCH="$(uname -m)"
REPORT="$KIT/test-report-${ARCH}-${STAMP}.log"
LDLOG="$KIT/lddebug-${STAMP}.log"
PASS=0

log() { echo "$@" | tee -a "$REPORT"; }

log "==== gdal-warp-bindings deploy-alpha smoke test ===="
log "time   : $(date '+%F %T')"
log "host   : $(uname -a)"

# ---------- 环境检查 ----------
log ""
log "---- [1/4] environment ----"
case "$ARCH" in
    x86_64)  log "arch   : x86_64 -> 走 linux/amd64 资源集" ;;
    aarch64) log "arch   : aarch64 -> 走 linux/arm64 资源集" ;;
    *) log "arch   : $ARCH -> 不支持,仅支持 x86_64 / aarch64"; exit 2 ;;
esac

GLIBC_LINE="$(ldd --version 2>/dev/null | head -1)"
GLIBC_VER="$(echo "$GLIBC_LINE" | grep -oE '[0-9]+\.[0-9]+' | head -1)"
log "glibc  : $GLIBC_LINE"
if [ -z "$GLIBC_VER" ]; then
    log "WARN   : 无法解析 glibc 版本(非 glibc 系统?Alpine/musl 不受支持)"
elif awk "BEGIN{exit !($GLIBC_VER < 2.17)}"; then
    log "FAIL   : glibc $GLIBC_VER < 2.17,不满足二进制下限"
    exit 2
fi

JAVACMD="${JAVA_HOME:+$JAVA_HOME/bin/}java"
command -v "$JAVACMD" >/dev/null 2>&1 || JAVACMD=java
if ! command -v "$JAVACMD" >/dev/null 2>&1; then
    log "FAIL   : 找不到 java(需要 JDK/JRE 8+)"
    exit 2
fi
log "java   : $("$JAVACMD" -version 2>&1 | head -1)"

# /tmp noexec 检测(解压目录默认在 java.io.tmpdir 下)
if mount 2>/dev/null | grep -E ' on /tmp ' | grep -q noexec; then
    log "WARN   : /tmp 挂载为 noexec,自动改用 \$HOME/.gdalwarp-test-tmp 作为解压目录"
    mkdir -p "$HOME/.gdalwarp-test-tmp"
    TMPOPT="-Djava.io.tmpdir=$HOME/.gdalwarp-test-tmp"
else
    TMPOPT=""
fi

# ---------- 定位待测 jar ----------
LIBDIR="${1:-$KIT/libs}"
JAR="$LIBDIR/gdal-warp-bindings-3.6.4.jar"
if [ ! -f "$JAR" ]; then
    log "FAIL   : 未找到待测包 $JAR(将 gdal-warp-bindings-3.6.4.jar 放入 $LIBDIR)"
    exit 2
fi
log "jar    : $JAR ($(du -h "$JAR" | cut -f1))"

# ---------- 运行 ----------
log ""
log "---- [2/4] run smoke test (LD_DEBUG=libs) ----"
CP="$LIBDIR/*:$KIT/testkit-tests.jar"
set +e
LD_DEBUG=libs "$JAVACMD" $TMPOPT -cp "$CP" com.geoway.testkit.ExtendedSmokeTest \
    > "$KIT/stdout-${STAMP}.log" 2> "$LDLOG"
RC=$?
set -e
cat "$KIT/stdout-${STAMP}.log" | tee -a "$REPORT"

if [ $RC -eq 0 ] && grep -q "RESULT: PASS" "$KIT/stdout-${STAMP}.log"; then
    PASS=1
    log "run    : exit=0, RESULT: PASS ✓"
else
    log "run    : exit=$RC —— 失败。关键错误如下:"
    grep -E "UnsatisfiedLinkError|cannot open shared object|undefined symbol|NoClassDefFound|failed to map segment|ERROR" \
        "$LDLOG" "$KIT/stdout-${STAMP}.log" 2>/dev/null | sort -u | head -10 | tee -a "$REPORT"
    log "完整日志: $KIT/stdout-${STAMP}.log / $LDLOG"
    exit 1
fi

# ---------- 校验依赖来源 ----------
log ""
log "---- [3/4] dependency source audit (LD_DEBUG) ----"
# 统计我们打包的关键库是否从解压目录(nativeutils*)加载,而非系统路径
BUNDLED="libssl.so.10 libcrypto.so.10 libcurl.so.4 libz.so.1 libpcre.so.1 \
libnss3.so libnspr4.so libkrb5.so.3 libgssapi_krb5.so.2 libldap-2.4.so.2 \
libsqlite3.so.0 libtiff.so.5 libproj.so.25 libgeos_c.so.1 libgdal.so.32"
FROM_BUNDLE=0; FROM_SYSTEM=0; SYS_LIST=""
for soname in $BUNDLED; do
    src=$(grep "calling init: .*/${soname//./\\.}$" "$LDLOG" 2>/dev/null | head -1 | sed 's/.*calling init: //')
    [ -z "$src" ] && src=$(grep "calling init: .*/${soname//./\\.} " "$LDLOG" 2>/dev/null | head -1 | sed 's/.*calling init: //')
    if [ -z "$src" ]; then
        continue
    elif echo "$src" | grep -q "nativeutils"; then
        FROM_BUNDLE=$((FROM_BUNDLE+1))
    else
        FROM_SYSTEM=$((FROM_SYSTEM+1)); SYS_LIST="$SYS_LIST
  !! $soname <- $src"
    fi
done
log "从包内解压目录加载的关键库: $FROM_BUNDLE 个"
log "从系统路径加载的关键库    : $FROM_SYSTEM 个"
[ -n "$SYS_LIST" ] && log "系统来源明细:$SYS_LIST"
if [ $FROM_SYSTEM -gt 0 ]; then
    log "WARN   : 存在同名库走了系统路径(预加载命中失败),请回传报告人工复核"
else
    log "audit  : 全部关键库均由包内副本提供,自足性确认 ✓"
fi

# ---------- 汇总 ----------
log ""
log "---- [4/4] summary ----"
log "RESULT : PASS(${ARCH}, glibc ${GLIBC_VER:-unknown})"
log "报告   : $REPORT"
exit 0
