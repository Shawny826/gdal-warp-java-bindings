package com.geoway.atlas.gdal.env;

import java.io.InputStream;
import java.util.*;
import java.util.stream.Collectors;


public class DepsReader {

    /**
     * DepsReader 类用于读取和管理不同架构下的依赖关系配置
     * 它通过加载一个名为 deps.properties 的属性文件来获取依赖信息
     */
    private Properties deps_properties;

    /**
     * 构造函数，初始化 DepsReader 对象
     * 它会创建一个 Properties 对象并加载依赖配置
     */
    public DepsReader() {
        deps_properties = new Properties();
        loadProperties();
    }

    public static final String DEPS_PROPERTIES_FILE = "deps.properties";

    public static final String AMD64_ARCHITECTURE= Arch.AMD64.NAME(); //"amd64";

    public static final String ARM64_ARCHITECTURE= Arch.ARM64.NAME();// "arm64";

    public static final String WINDOWS_ARCHITECTURE= Arch.WINDOWS.NAME()
            ;//"win";

    public enum DepsKey {
        BASE_LIBS("%s.base.libs"),
        PROJ_DB("%s.proj.db"),
        GDAL_LIB("%s.gdal.lib");

        private final String template;

        DepsKey(String template) {
            this.template = template;
        }

        public String getKey(String architecture) {
            return String.format(template, architecture);
        }
    }

    private List<String> deps_values(List<String> list) {
        return list.stream()
                .map(deps_properties::getProperty) // 使用方法引用简化
                .filter(Objects::nonNull) // 使用 Objects::nonNull 简化非空检查
                .flatMap(value -> Arrays.stream(value.split(","))) // 分割字符串并扁平化流
                .map(String::trim) // 再次 trim 分割后的字符串
                .filter(value -> !value.isEmpty()) // 移除空字符串
                .collect(Collectors.toList());
    }


    public final List<String> amd64_deps_keys =
            Arrays.asList(
                    DepsKey.BASE_LIBS.getKey(AMD64_ARCHITECTURE),
                    DepsKey.PROJ_DB.getKey(AMD64_ARCHITECTURE),
                    DepsKey.GDAL_LIB.getKey(AMD64_ARCHITECTURE)
                    );

    // 遍历amd64_deps_keys，并从deps_properties中获取该key对应的值，并返回一个List<String>
    private final List<String> amd64_deps_values() {
        return  Collections.unmodifiableList(deps_values(amd64_deps_keys));
    }


    public final List<String> arm64_deps_keys =
            Arrays.asList(
                    DepsKey.BASE_LIBS.getKey(ARM64_ARCHITECTURE),
                    DepsKey.PROJ_DB.getKey(ARM64_ARCHITECTURE),
                    DepsKey.GDAL_LIB.getKey(ARM64_ARCHITECTURE)
                    );

    private final List<String> arm64_deps_values(){
        return  Collections.unmodifiableList(deps_values(arm64_deps_keys));
    }

    public final List<String> win_deps_keys =
            Arrays.asList(
                    DepsKey.BASE_LIBS.getKey(WINDOWS_ARCHITECTURE),
                    DepsKey.PROJ_DB.getKey(WINDOWS_ARCHITECTURE),
                    DepsKey.GDAL_LIB.getKey(WINDOWS_ARCHITECTURE)
            );

    private final List<String> win_deps_values() {
        return Collections.unmodifiableList(deps_values(win_deps_keys));
    }

    // 根据输入的架构名称，返回对应的依赖项列表。
    public List<String> getDepsByArch(String architecture) {
        switch (architecture) {
            case "amd64":
            case "AMD64":
                return amd64_deps_values();
            case "arm64":
            case "ARM64":
                return arm64_deps_values();
            case "win":
            case "windows":
                return win_deps_values();
            default:
                throw new IllegalArgumentException("Invalid architecture: " + architecture);
        }
    }

    public List<String> getDepsByArch(Arch architecture) {
        return getDepsByArch(architecture.NAME());
    }

    /**
     * 获取绑定的 GDAL 版本号
     * 此方法会从 deps.properties 文件中查找 binding.version 属性
     * 如果未找到对应的版本信息，将抛出 IllegalArgumentException
     *
     * @return GDAL 绑定的版本号
     */
    public String getBindVersion() {
        String versionKey = "gdal.warp.binding.version";
        String versionValue = deps_properties.getProperty(versionKey);
        if (versionValue == null) {
            throw new IllegalArgumentException("No binding version found in deps.properties");
        }
        return versionValue.trim();
    }

    /**
     * 加载 deps.properties 文件中的配置
     * 此方法负责从类路径中找到 deps.properties 文件，并将其内容加载到 deps_properties 对象中
     * 如果文件找不到或加载过程中发生错误，将抛出 RuntimeException
     */
    private void loadProperties() {
        try (InputStream input = DepsReader.class.getClassLoader().getResourceAsStream(DEPS_PROPERTIES_FILE)) {
            if (input == null) {
                throw new RuntimeException("Sorry, unable to find deps.properties");
            }
            deps_properties.load(input);
        } catch (Exception ex) {
            throw new RuntimeException("Error loading deps.properties", ex);
        }
    }

//    public static void main(String[] args) {
//
//        DepsReader reader = new DepsReader();
//        System.out.println(Arch.ARM64.NAME());
//        System.out.println("AMD64 Dependencies: " + reader.getDepsByArch(Arch.AMD64));
//        System.out.println("ARM64 Dependencies: " + reader.getDepsByArch(Arch.ARM64));
//        System.out.println("Windows Dependencies: " + reader.getDepsByArch(Arch.WINDOWS));
//    }
}