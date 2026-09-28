# 三平台打包依赖完整性分析报告

> 分析日期:2026-09-28 · 分支:deploy-alpha · 结论基于对 jar 内二进制的实际依赖分析(ELF NEEDED / PE 导入表),非清单比对。
>
> **状态更新(2026-09-28)**:补救已完成——三平台依赖闭包已补齐入库,deps.properties 已重写为脚本生成的拓扑序,并通过"闭包 + 清单同步 + 拓扑序 + 双向符号级 ABI"四重静态校验。详见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。待办:干净环境运行时冒烟验证(本机被终端安全软件拦截 DLL 加载,详见下文"运行时验证"节)。

## 总体结论

| 平台 | deps.properties 声明 vs jar 内文件 | 运行期自足性 |
|---|---|---|
| linux/amd64 | 一一对应 ✓ | ✗ 缺 5 个系统库,且被 OpenSSL 1.0.2 钉死在 CentOS 7 系 |
| linux/arm64 | 一一对应 ✓ | △ 仅缺 libcurl.so.4、libz.so.1(+ curl 的传递闭包) |
| windows/win | 一一对应 ✓ | ✗ 一级缺约 20 个第三方 DLL,含 geos.dll、zlib.dll 等直接依赖 |

`deps.properties` 声明的文件全部存在于 jar;问题在声明清单本身没有覆盖二进制的真实依赖闭包。

## 二进制来源指纹(决定补包渠道)

| 平台 | 证据 | 结论 |
|---|---|---|
| linux/amd64 | `GCC: 4.8.5 20150623 (Red Hat 4.8.5-44)`,glibc 符号上限 2.15 | CentOS 7 原生构建 |
| linux/arm64 | `GCC: 7.3.1 (Red Hat 7.3.1-5)`(devtoolset-7),glibc 符号上限 2.17 | CentOS 7 aarch64 构建 |
| windows/win | gdal.dll 内嵌构建路径 `E:\buildsystem\release-1916-x64\` | GIS Internals release-1916(VS2019)x64,GDAL 3.6.4 |

## 各平台缺口明细

### Windows(缺口最大)

已验证的一级缺失(PE 导入表):

- tiff.dll → zlib.dll
- geos_c.dll → **geos.dll**(只打了 C 封装层,本体缺失)
- proj_9_1.dll → sqlite3.dll、libcurl.dll
- gdal.dll → zlib.dll、libcurl.dll、libxml2.dll、libcrypto-1_1-x64.dll、libssl-1_1-x64.dll、zstd.dll、xerces-c_3_2.dll、libpng16.dll、sqlite3.dll、LIBPQ.dll、openjp2.dll、pcre.dll、spatialite.dll、libmysql.dll、freexl.dll、ogdi.dll、libexpat.dll、iconv-2.dll
- gdalwarp_bindings-win64.dll → **pthreadVC2.dll**(pthreads-win32)

另需 VC++ 2015+ 运行库(MSVCP140/VCRUNTIME140)与 UCRT。二级闭包(brotli/nghttp2/libssh2/libintl-8 等)待补齐一级后用工具验证。

### Linux amd64

libgdal.so.32 的 NEEDED 中未打包:`libz.so.1`、`libcrypto.so.10`、`libssl.so.10`(OpenSSL 1.0.2 ABI,现代发行版默认无)、`libpcre.so.1`、`libcurl.so.4`。libsqlite3/libtiff 亦需 libz.so.1。

### Linux arm64

闭包检查后系统侧仅缺:`libcurl.so.4`、`libz.so.1`;但打包 libcurl 后会连带其闭包(含 libssl.so.10/libcrypto.so.10 及 libidn/libssh2/libldap 等,以容器内 lddtree 为准)。

## 最小完备清单(按加载拓扑序)

加载机制说明:现有代码靠 `System.load` 预加载注册 soname 解析依赖(libgdal RPATH 是构建机路径而非 `$ORIGIN`),**deps.properties 的顺序即拓扑序,不可随意调整**。

### linux/amd64

libz.so.1 → libcrypto.so.10 → libssl.so.10 → libpcre.so.1 → libcurl.so.4(+其闭包)→ libsqlite3.so.0 → libjbig.so.2.0 → libjpeg.so.62 → libtiff.so.5 → libgeos.so.3.10.2 → libgeos_c.so.1 → libproj.so.25 → proj.db → libgdal.so.32 → libgdalalljni.so
(系统基座:libc/libm/libdl/libpthread/ld-linux/libstdc++/libgcc_s)

### linux/arm64

libz.so.1 → libcurl.so.4(+其闭包,含 libssl.so.10/libcrypto.so.10)→ libsqlite3.so.0 → libjbig.so.2.0 → libjpeg.so.62 → libtiff.so.5 → libgeos.so.3.10.2 → libgeos_c.so.1 → libproj.so.25 → proj.db → libgdal.so.32 → libgdalalljni.so

### windows/win

zlib.dll → sqlite3.dll → libcurl.dll(及其依赖)→ libcrypto-1_1-x64.dll → libssl-1_1-x64.dll → geos.dll → tiff.dll → geos_c.dll → proj_9_1.dll →(其余 gdal.dll 直接依赖)→ gdal.dll → gdalalljni.dll;pthreadVC2.dll 由绑定库加载阶段需要。

## 依赖获取渠道(同源原则)

- **Windows**:下载 GIS Internals `release-1916-x64-gdal-3-6-4-mapserver-8-0-1.zip`(archive: https://gisinternals.com/archive.php ),其 `bin\` 即完整闭包;pthreadVC2.dll 若不在 bin\ 内,取 sourceforge pthreads-win32 2.9.1 Pre-built.2。
- **Linux 两架构**:用 manylinux2014 容器(CentOS 7 同源,yum 可用):
  - `quay.io/pypa/manylinux2014_x86_64`(amd64)
  - `quay.io/pypa/manylinux2014_aarch64`(arm64;x64 主机先 `docker run --privileged --rm multiarch/qemu-user-static --reset -p yes`)
  - 容器内 `yum install -y zlib openssl-libs pcre libcurl pax-utils && lddtree /usr/lib64/libcurl.so.4`,排除 glibc 基座七件套后全部复制,文件名保持 soname 原名。
  - 禁止从 Ubuntu/Debian 仓库取(libssl.so.3 / 更高 glibc 符号,破坏可移植性)。
- 无 Docker 替代:从 `vault.centos.org` 下载 el7 / el7.aarch64 RPM,`rpm2cpio | cpio -idmv` 解出。

## OpenSSL 版本不一致的影响结论

动态加载按 soname/文件名精确匹配,不存在"混版注入":宿主装有 1.1/3.x 不会被用于满足 `libssl.so.10`,只会报 library not found。因此:

1. 不打包(现状):宿主必须恰好提供同 soname;同 soname 不同 patch 还可能缺导出符号。
2. 打包精确副本并按拓扑序预加载(推荐):整条 GDAL 链命中打包副本,宿主 OpenSSL 版本完全无关;前提是 curl 等也用打包副本,避免一进程两套 OpenSSL。
3. JVM 自身 TLS 走 JSSE(纯 Java),与 native OpenSSL 无冲突。

遗留风险:打包等于固化 OpenSSL 1.0.2(已 EOL),安全补丁需自行换文件重发。

## 其他待办(与本轮打包相关)

- [ ] Windows/Linux 补齐上述闭包文件,重写 deps.properties 为拓扑序
- [ ] 显式 `System.setProperty("PROJ_LIB", tmpDir)`(当前依赖 PROJ 7+ 同目录回退查找 proj.db)
- [ ] 清理冗余打包物:`bindings/bak/`(4.9MB)、amd64 目录未声明的 libgeos.so/libgeos_c.so 副本(~3.6MB)、两平台 libpthread.so.0(glibc 自带,永不被加载)、无 mac 支持却打包的 libgdalwarp_bindings-amd64.dylib
- [ ] 评估 `GDALEnv` 中 `System.exit(-1)` 的库内杀进程行为
- [ ] 长期:用 vcpkg/自编译产出精简版 GDAL(--without-curl --without-xml2 等),把闭包缩到个位数
- [ ] 随包补第三方许可文本(OpenSSL、OpenJPEG、libjpeg 等)

## 验证方式

1. Linux:同容器内对每个库迭代 `ldd`(或 lddtree)确认除 glibc 基座外无缺项。
2. Windows:用 Dependencies(lucasg)对拼好的目录跑传递闭包检查。
3. 冒烟:在干净目标系统容器/虚机运行 `com.azavea.gdal.test.GDALWarpTest`。

## 补救实施记录(2026-09-28)

- **Linux 两架构**:经阿里云 centos-vault 镜像取 CentOS 7.9 官方 RPM(与构建环境同源),`bsdtar`(Windows 自带 libarchive)解包,各补 24 个库;闭包经 readelf 全量验证。
- **Windows**:因 download.gisinternals.com 被网络封锁,改用 **OSGeo4W v2**(DLL 命名与 GIS Internals 完全一致,同为 MSVC 构建,ABI 兼容)按 gdal 3.6.4 同期版本补齐 27 个 DLL;pcre.dll 取自 conda-forge 8.45(VS2019 构建);pthreadVC2.dll 取自 sourceware 官方 pthreads-w32 2.9.1 x64;msvcr100.dll 取自微软官方 VC++ 2010 SP1 x64 redist。**geos_c.dll 替换为 OSGeo4W 3.11.2**(与补入的 geos.dll 配对)。
- **加载顺序**:由依赖图 Kahn 拓扑排序生成(脚本),并通过断言校验"每个库的依赖均排在其前"。曾发现并修正:部分图生成的顺序遗漏了仓库原有库的依赖边(libproj→sqlite3/tiff/curl、amd64 libtiff/sqlite3→libz)导致错序,最终版使用全量图。
- **ABI 校验**:对 Windows 全部 DLL 做了双向符号级校验(导入方所需符号 ⊆ 提供方导出表),零缺失。
- **清理**:移除 bindings/bak/(4.9MB)、amd64 未声明的 libgeos.so/libgeos_c.so 副本、两平台 libpthread.so.0、无 mac 支持的 amd64 dylib;JAR 体积 72MB,无冗余资源。
- **PROJ 数据路径**:未在 Java 侧显式设置 PROJ_LIB(原生 PROJ 无法读取 Java 系统属性);依赖 PROJ 7+ "共享库同目录回退"(libproj.so.25 / proj_9_1.dll 与 proj.db 同在解压目录)。若消费方进程环境已有 PROJ_LIB/PROJ_DATA,以环境变量优先——与包内 proj.db 同为 9.1 数据格式,无冲突。
- **运行时验证(受阻)**:本机冒烟测试被终端安全软件(火绒 HipsDaemon/wsctrlsvc;Defender 实时保护为关闭状态)以 err=5 拦截,连 9 月 21 日曾成功加载的原版 DLL 也被拒,确认为整机策略而非包缺陷。待在干净 Windows 机器/VM 或 Linux 服务器上执行 `GDALWarpTest` 完成最终确认。
