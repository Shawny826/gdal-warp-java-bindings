# deploy-alpha 一键测试包(Linux amd64 / arm64)

## 目的

验证 `gdal-warp-bindings-3.6.4.jar`(deploy-alpha 分支)在目标机上开箱即用:
全部原生依赖按拓扑序解压加载成功、JNI 绑定可用、GDAL 核心完成初始化,
并确认关键库由包内副本提供(不借用目标机系统库)。

## Docker 容器化测试(推荐)

容器是**最干净的自足性证明**——环境里没有任何预装 GDAL/OpenSSL 库,跑通即证明不依赖宿主机。
在任意装有 docker 的 VPS 上,解压测试包后:

```bash
bash docker-test.sh                 # 默认:temurin8 / ubuntu24+jdk17 / centos7+jdk8 / alpine(预期失败)
DOCKER_PREFIX=docker.m.daocloud.io/ bash docker-test.sh   # 国内 VPS 拉镜像失败时
ENABLE_QEMU=1 bash docker-test.sh   # x86_64 VPS 上附加 arm64 模拟用例
```

测试矩阵含义:
| 用例 | 验证点 |
|---|---|
| temurin8 | Debian 系 + JDK8 基准 |
| ubuntu24-jdk17 | 最新 glibc 2.39 + JDK17(与目标测试服务器同款) |
| centos7-jdk8 | glibc 2.17 下限(与二进制同源环境) |
| alpine-musl | musl 不支持,验证失败检测有效(预期 FAIL,记 PASS*) |
| sim-arm64 | qemu 模拟另一架构(可选,建议真机复测) |

## 使用

```bash
# 1. 将 gdal-warp-testkit-linux.zip 拷到目标机(scp/U盘均可)
unzip gdal-warp-testkit-linux.zip
cd gdal-warp-testkit

# 2. 一键执行(自动识别 x86_64 / aarch64)
bash run-test.sh

# 3. 回传生成的报告
test-report-*.log  lddebug-*.log
```

要求:目标机 glibc ≥ 2.17(主流发行版均满足)。
**Java 自动供给**:脚本优先使用环境已有 java(≥8,含 JAVA_HOME);若没有,
自动下载**便携版 OpenJDK 8(Temurin)到 `~/.gdalwarp-test-jdk`**(仅测试自用,
不装系统、不改 JAVA_HOME/PATH、不覆盖任何已有 Java)。下载源:清华 Adoptium
镜像(主)+ Adoptium API(备),x64/aarch64 对称支持。
**注意**:Oracle JDK 归档(如 8u202-x64、8u271-aarch64)现已强制 SSO 登录,
无法脚本直连;如需精确 Oracle 版本,请从
[Oracle 归档页](https://www.oracle.com/java/technologies/javase/javase8u211-later-archive-downloads.html)
浏览器下载后解压到 `~/.gdalwarp-test-jdk/`,或执行时指定
`JAVA_HOME=<jdk目录> bash run-test.sh`(脚本会自动识别复用)。
`/tmp` 为 noexec 时脚本自动改用 `~/.gdalwarp-test-tmp`。

## 判定

- 退出码 0 且输出 `RESULT: PASS` → 通过;
- `RESULT: PASS` + `dependency source audit` 无 WARN → 自足性同时确认;
- 失败时脚本直接打印缺失的库名/符号与日志位置,原样回传即可。

## 文件说明

| 文件 | 作用 |
|---|---|
| `libs/gdal-warp-bindings-3.6.4.jar` | 被测构件 |
| `libs/*.jar`(其余) | slf4j/log4j 运行日志依赖 |
| `testkit-tests.jar` | 扩展冒烟类(init + 版本读取 + deinit) |
| `run-test.sh` | 一键入口:环境检查 → 冒烟 → 依赖来源审计 |

## 从源码重组测试包

```bash
mvn clean package -DskipTests
mvn dependency:copy-dependencies -DincludeScope=runtime -DoutputDirectory=kit-libs
javac -d test-classes tools/testkit/src/com/geoway/testkit/ExtendedSmokeTest.java
jar cf testkit-tests.jar -C test-classes .
# 将 gdal-warp-bindings-3.6.4.jar、kit-libs/*、testkit-tests.jar、run-test.sh、README.md 打包
```
