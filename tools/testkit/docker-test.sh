#!/usr/bin/env bash
# deploy-alpha 容器化测试矩阵(Linux amd64/arm64 通用)
# 用法: 在装有 docker 的机器上,进入解压后的 gdal-warp-testkit 目录执行:
#        bash docker-test.sh
# 环境变量(可选):
#   DOCKER_PREFIX  镜像仓库前缀(直连 docker hub 不通时用国内镜像,
#                  例: DOCKER_PREFIX=docker.m.daocloud.io/)
#   ENABLE_QEMU=1  在 x86_64 VPS 上附加 arm64 模拟用例(需先能拉 multiarch/qemu-user-static)

set -u
KIT="$(cd "$(dirname "$0")" && pwd)"
P="${DOCKER_PREFIX:-}"
RESULTS=""

record() { RESULTS="${RESULTS}${1}|${2}|${3}
"; printf '%-24s %-6s %s\n' "$1" "$2" "$3"; }

run_container() { # name image prelude
    local name="$1" image="$2" prelude="${3:-}"
    echo "================================================================"
    echo ">> $name  (image: $image)"
    if ! docker image inspect "$image" >/dev/null 2>&1 \
       && ! docker pull -q "$image" >/dev/null 2>&1; then
        record "$name" "SKIP" "镜像不可达:$image"
        return
    fi
    docker run --rm -v "$KIT:/kit" "$image" bash -c "${prelude:+$prelude
}cd /kit && bash run-test.sh /kit/libs" > "$KIT/docker-${name}.log" 2>&1
    local rc=$?
    if [ $rc -eq 0 ] || grep -q "RESULT : PASS" "$KIT/docker-${name}.log" 2>/dev/null; then
        record "$name" "PASS" "详见 docker-${name}.log"
    else
        record "$name" "FAIL" "退出码 $rc,详见 docker-${name}.log"
    fi
}

echo "arch: $(uname -m)   kit: $KIT"
echo ""

# 1) 基准:temurin 官方 JDK8 镜像(Debian 系,glibc 2.3x)
run_container temurin8 "${P}eclipse-temurin:8-jre"

# 2) 现代环境:ubuntu 24.04(与目标测试服务器同款,glibc 2.39)+ JDK17
run_container ubuntu24-jdk17 "${P}ubuntu:24.04" \
    "apt-get update -qq && apt-get install -y -qq openjdk-17-jre-headless >/dev/null"

# 3) 下限边界:CentOS 7(glibc 2.17,与二进制同源)+ OpenJDK 8
run_container centos7-jdk8 "${P}centos:7" \
    "sed -i -e 's|^mirrorlist=|#mirrorlist=|' -e 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|' /etc/yum.repos.d/*.repo && yum install -y -q java-1.8.0-openjdk-headless wget >/dev/null 2>&1 || (sed -i 's|vault.centos.org|mirrors.aliyun.com/centos-vault|' /etc/yum.repos.d/*.repo && yum install -y -q java-1.8.0-openjdk-headless >/dev/null 2>&1)"

# 4) 反向验证:Alpine(musl)应明确失败,证明脚本的失败检测有效
echo "================================================================"
echo ">> alpine-musl(预期失败:glibc 二进制不支持 musl)"
docker run --rm -v "$KIT:/kit" "${P}alpine:3.19" sh -c \
    "apk add -q openjdk17-jre-headless bash >/dev/null 2>&1 && cd /kit && bash run-test.sh /kit/libs" \
    > "$KIT/docker-alpine-musl.log" 2>&1
if [ $? -eq 0 ]; then
    record alpine-musl "WARN" "意外通过?请人工复核 docker-alpine-musl.log"
else
    record alpine-musl "PASS*" "按预期失败,失败检测有效"
fi

# 5) 可选:qemu 跨架构模拟(x86_64 VPS 上模拟 arm64)
if [ "${ENABLE_QEMU:-0}" = "1" ]; then
    docker run --privileged --rm "${P}multiarch/qemu-user-static" --reset -p yes >/dev/null 2>&1 || true
    if [ "$(uname -m)" = "x86_64" ]; then
        echo "================================================================"
        echo ">> sim-arm64(qemu 模拟 linux/arm64)"
        docker run --rm --platform linux/arm64 -v "$KIT:/kit" "${P}eclipse-temurin:8-jre" \
            bash -c "cd /kit && bash run-test.sh /kit/libs" > "$KIT/docker-sim-arm64.log" 2>&1
        if [ $? -eq 0 ] || grep -q "RESULT : PASS" "$KIT/docker-sim-arm64.log" 2>/dev/null; then
            record sim-arm64 "PASS" "qemu 模拟 arm64 通过(建议真机复测)"
        else
            record sim-arm64 "FAIL" "详见 docker-sim-arm64.log"
        fi
    fi
fi

# 汇总
echo ""
echo "==================== SUMMARY ===================="
printf '%s' "$RESULTS" | awk -F'|' '{printf "%-24s %-6s %s\n", $1, $2, $3}'
echo "================================================"
echo "本机架构 $(uname -m),执行的是对应平台资源集;另一架构请在对应硬件上跑,或 ENABLE_QEMU=1 模拟。"
