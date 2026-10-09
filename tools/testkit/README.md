# deploy-alpha 一键测试包(Linux amd64 / arm64)

## 目的

验证 `gdal-warp-bindings-3.6.4.jar`(deploy-alpha 分支)在目标机上开箱即用:
全部原生依赖按拓扑序解压加载成功、JNI 绑定可用、GDAL 核心完成初始化,
并确认关键库由包内副本提供(不借用目标机系统库)。

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

要求:目标机有 java 8+(任意发行版)、glibc ≥ 2.17(主流发行版均满足)。
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
