package com.geoway.atlas.gdal.env;

/**
 * @description: TODO
 * @author shenyongjie
 * @date 2025/2/11 9:12
 * @version 1.0
 */

public enum Arch {
    AMD64("amd64"),
    ARM64("arm64"),
    WINDOWS("win");

    private final String name;

    Arch(String name) {
        this.name = name;
    }

    public String NAME() {
        return name;
    }
}
