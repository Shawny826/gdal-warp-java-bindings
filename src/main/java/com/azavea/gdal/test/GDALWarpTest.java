package com.azavea.gdal.test;

import com.azavea.gdal.GDALWarp;

public class GDALWarpTest {
/**
 * @description: TODO
 * @author shenyongjie
 * @date 2025/2/13 9:11
 * @version 1.0
 */

    public static void main(String[] args) {
        try {
            // Initialize GDALWarp with a size parameter
            GDALWarp.init(1 << 20);
            System.out.println("GDALWarp initialized successfully.");
        } catch (Exception e) {
            System.err.println("Failed to initialize GDALWarp: " + e.getMessage());
            e.printStackTrace();
        }
    }

}
