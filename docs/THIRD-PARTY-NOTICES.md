# 第三方原生依赖来源与许可清单(deploy-alpha)

本分支为三平台补齐的原生依赖闭包。所有条目均可再分发;按平台与来源列出。
获取与校验方式:Linux 来自 CentOS 7.9 vault(阿里云镜像)RPM;Windows 来自 OSGeo4W v2 官方源、conda-forge、sourceware 官方、微软官方 redist。

## Linux amd64 / arm64(两架构同源同版本)

| 库文件 | 版本 | 上游许可 |
|---|---|---|
| libz.so.1 | 1.2.7 | Zlib |
| libcrypto.so.10 / libssl.so.10 | 1.0.2k | OpenSSL License |
| libpcre.so.1 | 8.32 | BSD |
| libcurl.so.4 | 7.29.0 | curl (MIT 类) |
| libidn.so.11 | 1.28 | LGPL-2.1+ |
| libssh2.so.1 | 1.8.0 | BSD |
| libldap-2.4.so.2 / liblber-2.4.so.2 | 2.4.44 | OpenLDAP Public License |
| libsasl2.so.3 | 2.1.26 | BSD (部分 LGPL) |
| libnss3.so / libsmime3.so / libssl3.so | 3.90.0 | MPL-2.0 |
| libnssutil3.so | 3.90.0 | MPL-2.0 |
| libnspr4.so / libplc4.so / libplds4.so | 4.35.0 | MPL-2.0 |
| libgssapi_krb5.so.2 / libkrb5.so.3 / libk5crypto.so.3 / libkrb5support.so.0 | 1.15.1 | MIT |
| libcom_err.so.2 | 1.42.9 | e2fsprogs (MIT 类) |
| libkeyutils.so.1 | 1.5.8 | LGPL-2.1+ |
| libselinux.so.1 | 2.5 | LGPL-2.1+(动态链接) |

说明:NSS/Kerberos/OpenLDAP 是 CentOS 7 的 libcurl 的强制传递依赖,非 GDAL 直接使用。
OpenSSL 1.0.2 已 EOL,安全补丁需随包升级重发。

## Windows x64

| DLL | 版本 | 来源 | 许可 |
|---|---|---|---|
| zlib.dll | 1.3.1 | OSGeo4W zlib | Zlib |
| libcurl.dll | 8.1.2 | OSGeo4W curl | curl |
| libcrypto-1_1-x64.dll / libssl-1_1-x64.dll | 1.1.1w | OSGeo4W openssl | OpenSSL License |
| liblzma.dll | 5.4.7 | OSGeo4W xz | 公有领域(解压)/LGPL-2.1+ |
| brotlicommon/dec/enc.dll | 1.0.9 | OSGeo4W brotli | MIT |
| sqlite3.dll | 3.41.1 | OSGeo4W sqlite3 | 公有领域 |
| geos.dll / geos_c.dll | 3.11.2 | OSGeo4W geos | LGPL-2.1+(动态链接) |
| libxml2.dll | 2.12.5 | OSGeo4W libxml2 | MIT |
| xerces-c_3_2.dll | 3.2.5 | OSGeo4W xerces-c | Apache-2.0 |
| libpng16.dll | 1.6.37 | OSGeo4W libpng | libpng(Zlib 类) |
| openjp2.dll | 2.5.2 | OSGeo4W openjpeg | BSD-2 |
| spatialite.dll | 5.0.1 | OSGeo4W libspatialite | MPL-1.1 / GPL-2+ / LGPL-2.1+(三许可) |
| libpq.dll | 15.2 | OSGeo4W libpq | PostgreSQL License |
| libmysql.dll | 8.0.21 | OSGeo4W libmysql | GPL-2.0(附带例外)/ MySQL FOSS 例外 |
| freexl.dll | 1.0.6 | OSGeo4W freexl | MPL-1.1 / GPL-2+ / LGPL-2.1+ |
| ogdi.dll | 4.1.1 | OSGeo4W ogdi | GPL-2.0(API LGPL)|
| libexpat.dll | 2.7.5 | OSGeo4W expat | MIT |
| iconv-2.dll | 1.17 | OSGeo4W libiconv | LGPL-2.1+(动态链接) |
| zstd.dll | 1.5.5 | OSGeo4W zstd | BSD / GPLv2 双许可 |
| proj_9_2.dll | 9.2.1 | OSGeo4W proj92-runtime | MIT |
| pcre.dll | 8.45 | conda-forge pcre(VS2019 构建) | BSD |
| pthreadVC2.dll | 2.9.1 x64 | sourceware 官方 pthreads-w32 | LGPL-2.1(动态链接) |
| msvcr100.dll | 10.00.40219.1 | 微软官方 VC++ 2010 SP1 x64 redist(download.microsoft.com 的 vcredist_x64.exe,静态解包内嵌 vc_red.cab 获得) | 微软再分发条款 |

## 重要替换/共存说明

1. **geos_c.dll 被替换**为 OSGeo4W 3.11.2 构建(与补入的 geos.dll 配对;GEOS C API 向后兼容,已通过符号级校验)。
2. **proj_9_2.dll 与 proj_9_1.dll 共存**:gdal.dll 走 proj_9_1 + 包内 proj.db(一致);proj_9_2 仅被 spatialite.dll 引用,spatialite 内部 CRS 操作可能因 proj.db 版本差异受限(不影响 GDAL 自身坐标系功能)。
3. 运行库基座要求:Windows 需 VC++ 2015-2022 运行库(msvcp140/vcruntime140,未随包)与 UCRT;Linux 需 glibc ≥ 2.17 与 libstdc++/libgcc_s(所有主流发行版默认满足)。
