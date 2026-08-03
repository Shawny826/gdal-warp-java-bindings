## GDAL Warp Bindings 稳健性评估

### 评估范围

本次评估覆盖 `D:\Code\IDEA\gdal-warp-bindings-gw` 当前工作副本，重点检查 Maven 构建、JNI/native 加载链、资源契约、平台兼容性、测试覆盖和发布可维护性。

### 总体结论

该项目的**编译与打包链路基本可用，但运行时稳健性偏低**。如果作为固定环境下的内部 Maven artifact 使用，风险可以通过人工验证控制；如果作为通用 Java 库被服务端、批处理、Spark executor 或长生命周期进程依赖，当前失败隔离、平台兼容和自动化验证都不足。

| 维度 | 评分 | 说明 |
| --- | ---: | --- |
| 构建稳健性 | 6/10 | `mvn test`、`mvn package` 可成功，但 `mvn clean test` 被 `target/test-classes` 删除失败阻断。 |
| 运行稳健性 | 3/10 | Windows native smoke test 实际失败，加载 `tiff.dll` 报 `拒绝访问`。 |
| 可维护性 | 4/10 | 资源布局清晰，但 native 资源、版本和平台判断缺少系统校验。 |
| 测试保障 | 2/10 | 没有标准 `src/test/java` 自动化测试，现有 smoke test 位于 `src/main/java`。 |

### 关键风险

1. **Windows native 初始化当前不可用。**  
   执行 `com.azavea.gdal.test.GDALWarpTest` 失败，报错为 `UnsatisfiedLinkError: ...\tiff.dll: 拒绝访问`，失败点在 `GDALEnv.copyAndLoadFile()` 的 `System.load()`。

2. **库代码会在失败时终止宿主 JVM。**  
   `GDALWarp` 静态初始化失败后调用 `System.exit(-1)`，`GDALEnv` 加载 GDAL 依赖失败也调用 `System.exit(-1)`。这对被嵌入业务系统的库来说风险很高。

3. **平台识别不完整。**  
   `deps.properties` 注释包含 `amd64 | x86_64`，但代码主要判断 `amd64` 或 `amd`。Linux JVM 常见的 `os.arch=x86_64` 可能无法正确命中。

4. **macOS 支持契约不一致。**  
   `GDALWarp` 有 `.dylib` 加载分支，但 `GDALEnv` 没有 macOS GDAL runtime 分支和资源目录，实际初始化会先失败。

5. **资源一致性缺少构建期校验。**  
   `DepsReader` 对缺失 key 会静默过滤，配置错误可能推迟到 native load 阶段才暴露。

6. **测试体系不足。**  
   `mvn test` 没有执行实际 Surefire 测试。`GDALWarpTest` 是 `main` 方法，且被打进正式 artifact。

7. **产物包含备份 native 文件。**  
   `resources/bindings/bak/**` 会进入 jar，增加包体并混淆 native 版本来源。

### 验证记录

```powershell
mvn test
# BUILD SUCCESS，但没有标准 src/test/java 测试。

mvn clean test
# BUILD FAILURE，clean 阶段无法删除 target/test-classes。

mvn package
# BUILD SUCCESS，jar 打包成功。

java -cp "target\classes;<dependency-classpath>" com.azavea.gdal.test.GDALWarpTest
# UnsatisfiedLinkError: ...\tiff.dll: 拒绝访问。
```

补充验证：将 `java.io.tmpdir` 改到项目 `target/runtime-tmp` 后，仍然在加载 `tiff.dll` 时出现同样的 `拒绝访问`，因此不像是单纯的用户 `%TEMP%` 目录权限问题。

### 改进优先级

| 优先级 | 建议 | 目标 |
| --- | --- | --- |
| P0 | 修复 Windows native smoke test | 先证明当前主平台可运行。 |
| P0 | 移除库内 `System.exit(-1)` | 失败时抛出明确异常，不杀宿主 JVM。 |
| P1 | 修正 `os.arch` 归一化 | 覆盖 `amd64`、`x86_64`、`aarch64`、`arm64`。 |
| P1 | 补资源一致性测试 | 确认 `deps.properties` 中声明的文件都存在。 |
| P1 | 建立 `native-smoke` Maven profile | 区分普通单元测试和真实 native 初始化验证。 |
| P2 | 排除 `bindings/bak/**` | 降低包体和误发旧二进制风险。 |
| P2 | 明确 macOS 支持策略 | 要么补齐资源，要么删除不可用分支。 |

### 结论判定

当前版本可以作为“受控环境内部包”继续使用，但不建议直接作为高稳健性通用库发布。下一阶段应优先处理 native 初始化失败和失败隔离问题，再补平台矩阵与自动化 smoke test。
