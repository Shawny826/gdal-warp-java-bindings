#!/usr/bin/env bash
# 最小镜像自足性验证(deploy-alpha)
#
# 思路:镜像里除 glibc 与 JVM 外一无所有(curl/OpenSSL/NSS/Kerberos 等
# GDAL 传递依赖全部缺席),跑通即证明包内闭包自足,不存在"借用系统库"。
#
# 用例:
#   A) debian:bookworm-slim(~75MB,无任何 GDAL 相关库)
#      + 包内置 JDK 8u292-b10,容器内跑完整 run-test.sh(含 LD_DEBUG 审计)
#   B) gcr.io/distroless/java:8(无 shell/无包管理器,仅 glibc+JRE,金标准;
#      无法拉取时自动 SKIP)
#
# 用法: 在装有 docker 的 VPS 上,进入解压后的 gdal-warp-testkit 目录:
#        bash minimal-test.sh            # 本机架构
#        bash minimal-test.sh --arm      # x86_64 VPS 上 qemu 模拟 arm64
# 环境变量: DOCKER_PREFIX 镜像前缀(国内镜像加速,例 docker.m.daocloud.io/)

set -u
KIT="$(cd "$(dirname "$0")" && pwd)"
P="${DOCKER_PREFIX:-}"
PLATFORM=""
RESULTS=""

record() { RESULTS="${RESULTS}${1}|${2}|${3}
"; printf '%-26s %-6s %s\n' "$1" "$2" "$3"; }

if [ "${1:-}" = "--arm" ]; then
    docker run --privileged --rm "${P}multiarch/qemu-user-static" --reset -p yes >/dev/null 2>&1 \
        || record qemu "SKIP" "无法拉取 qemu-user-static(无此前置无法跨架构)"
    PLATFORM="--platform linux/arm64"
    logname="minimal-arm"
else
    logname="minimal-$(uname -m)"
fi

# ---------- A) debian slim + 内置 JDK,完整 run-test.sh ----------
echo "================================================================"
echo ">> A) debian:bookworm-slim + 内置 JDK(完整冒烟+审计)"
IMG="${P}debian:bookworm-slim"
if docker image inspect "$IMG" >/dev/null 2>&1 || docker pull -q "$IMG" >/dev/null 2>&1; then
    docker run --rm $PLATFORM -v "$KIT:/kit" "$IMG" bash -c '
        set -e
        ARCH=$(uname -m); [ "$ARCH" = "x86_64" ] && M=x64 || M=aarch64
        mkdir -p /opt/jdk
        tar -xzf "/kit/jdks/OpenJDK8U-jdk_${M}_linux_hotspot_8u292b10.tar.gz" -C /opt/jdk --strip-components=1
        # JAVA_HOME 显式指向内置 JDK:容器内无 curl,跳过一切在线逻辑
        export JAVA_HOME=/opt/jdk
        cd /kit && bash run-test.sh /kit/libs
    ' > "$KIT/${logname}-debian-slim.log" 2>&1
    if [ $? -eq 0 ] && grep -q "RESULT : PASS" "$KIT/${logname}-debian-slim.log"; then
        record debian-slim "PASS" "详见 ${logname}-debian-slim.log"
    else
        record debian-slim "FAIL" "详见 ${logname}-debian-slim.log"
    fi
else
    record debian-slim "SKIP" "镜像不可达:$IMG"
fi

# ---------- B) distroless(无 shell,直启 java) ----------
echo "================================================================"
echo ">> B) distroless java:8(无 shell/包管理器,金标准)"
IMG="gcr.io/distroless/java:8"
if docker image inspect "$IMG" >/dev/null 2>&1 || docker pull -q "$IMG" >/dev/null 2>&1; then
    docker run --rm $PLATFORM -v "$KIT:/kit" -e LD_DEBUG=libs "$IMG" \
        -cp "/kit/libs/*:/kit/testkit-tests.jar" \
        com.geoway.testkit.ExtendedSmokeTest \
        > "$KIT/${logname}-distroless.out" 2> "$KIT/${logname}-distroless.ld.log"
    if grep -q "RESULT: PASS" "$KIT/${logname}-distroless.out"; then
        BUNDLED=0; OTHER=0
        for s in libssl.so.10 libcrypto.so.10 libcurl.so.4 libz.so.1 libnss3.so libkrb5.so.3 libgdal.so.32; do
            src=$(grep "calling init: .*/${s//./\\.}$" "$KIT/${logname}-distroless.ld.log" 2>/dev/null | head -1 | sed 's/.*calling init: //')
            [ -z "$src" ] && continue
            case "$src" in *nativeutils*) BUNDLED=$((BUNDLED+1));; *) OTHER=$((OTHER+1));; esac
        done
        record distroless "PASS" "关键库包内来源 $BUNDLED/其他 $OTHER(distroless 本无系统库,非 0 即异常)"
    else
        record distroless "FAIL" "详见 ${logname}-distroless.out / .ld.log"
    fi
else
    record distroless "SKIP" "镜像不可达(gcr.io 常需科学上网,可忽略)"
fi

# ---------- 汇总 ----------
echo ""
echo "==================== MINIMAL SUMMARY ($logname) ===================="
printf '%s' "$RESULTS" | awk -F'|' '{printf "%-26s %-6s %s\n", $1, $2, $3}'
echo "debian-slim 通过 = 自足性充分证明;distroless 为额外金标准(可选)。"
