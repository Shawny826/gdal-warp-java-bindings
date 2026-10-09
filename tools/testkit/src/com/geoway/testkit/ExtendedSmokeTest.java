package com.geoway.testkit;

import com.azavea.gdal.GDALWarp;

/**
 * deploy-alpha 依赖闭包扩展冒烟测试:
 * 1. 触发 GDALWarp 静态初始化(GDALEnv 按拓扑序解压并加载全部原生依赖 + JNI 绑定)
 * 2. 读取 GDAL 版本信息,证明 GDAL 核心完成初始化(而非仅加载成功)
 * 3. 反初始化,验证干净退出
 */
public class ExtendedSmokeTest {

    public static void main(String[] args) throws Exception {
        System.out.println("[testkit] os=" + System.getProperty("os.name")
                + " arch=" + System.getProperty("os.arch")
                + " java=" + System.getProperty("java.version")
                + " tmpdir=" + System.getProperty("java.io.tmpdir"));

        // 静态块会先执行一次 init;再次调用为幂等
        GDALWarp.init(1 << 20);
        System.out.println("[testkit] native libs loaded (GDALEnv + bindings)");

        String release = GDALWarp.get_version_info("RELEASE_NAME");
        System.out.println("[testkit] GDAL RELEASE_NAME = " + release);
        if (release == null || !release.contains("3.6")) {
            throw new IllegalStateException("unexpected GDAL version: " + release);
        }

        String build = GDALWarp.get_version_info("BUILD_INFO");
        String firstLine = build == null ? "" : build.split("\n")[0];
        System.out.println("[testkit] GDAL BUILD_INFO head = " + firstLine);

        GDALWarp.deinit();
        System.out.println("[testkit] RESULT: PASS");
    }
}
