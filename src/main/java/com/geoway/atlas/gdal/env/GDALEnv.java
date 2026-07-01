package com.geoway.atlas.gdal.env;

import com.azavea.gdal.GDALWarp;
import cz.adamh.utils.NativeUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.InputStream;
import java.io.UnsupportedEncodingException;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;

/**
 * GDAL基础动态库部署
 */

public class GDALEnv {

    private static DepsReader depsReader;

    public static String GDAL_WARP_BINDING_VERSION;

    private static final Logger logger = LoggerFactory.getLogger(GDALEnv.class);

    // resource资源路径: resources/gdal/${version}/${os}/${arch}/${filename}
    private static void copyAndLoadFile(String filepath, String filename, File tmpDir) {
        try {
            String resourcePath = filepath + "/" + filename;
            logger.info(Objects.requireNonNull(NativeUtils.class.getResource(resourcePath)).toString());
            File tempFile = new File(tmpDir, filename);
            try (InputStream is = NativeUtils.class.getResourceAsStream(resourcePath)) {
                assert is != null;
                Files.copy(is, tempFile.toPath(), StandardCopyOption.REPLACE_EXISTING);
                if (!filename.equals("proj.db")) {
                    System.load(tempFile.getAbsolutePath());
                }
            }
        } catch (Exception e) {
            logger.error("{}: [ERROR]{}", GDALEnv.class.getName(), String.format("Failed to copy and load file: %s\nCause: %s", filename, Arrays.toString(e.getStackTrace())));
            System.exit(-1);
        }
    }

    public static void init(String osName, String archName, String tmpDir) throws Exception {

        depsReader = new DepsReader();
        GDAL_WARP_BINDING_VERSION = depsReader.getBindVersion();
        logger.info("GDAL Version:{}", GDAL_WARP_BINDING_VERSION);

        if (osName.contains("linux") && archName.contains("amd")){
            for (String filename : depsReader.getDepsByArch(Arch.AMD64)){
                String filepath =
                        String.format("/resources/gdal/%s/%s/%s",GDAL_WARP_BINDING_VERSION,"linux",Arch.AMD64.NAME());
                copyAndLoadFile(filepath, filename, new File(tmpDir));
            }
        }
        else if ((osName.contains("linux") && archName.contains("aarch")) ||
                (osName.contains("linux") && archName.contains("arm"))) {
            for (String filename : depsReader.getDepsByArch(Arch.ARM64)){
                String filepath =
                        String.format("/resources/gdal/%s/%s/%s",GDAL_WARP_BINDING_VERSION,"linux",Arch.ARM64.NAME());
                copyAndLoadFile(filepath, filename, new File(tmpDir));
            }
        }
        else if (osName.contains("win")){
            for (String filename : depsReader.getDepsByArch(Arch.WINDOWS)){
                String filepath =
                        String.format("/resources/gdal/%s/%s/%s",GDAL_WARP_BINDING_VERSION,"windows",Arch.WINDOWS.NAME());
                copyAndLoadFile(filepath, filename, new File(tmpDir));
            }
        }
        else {
            throw new Exception(String.format("Unsupported platform: OS[%s]-ARCH[%s]",osName,archName));
        }
    }

}
