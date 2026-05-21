// 強制修改 sdk.dir 為 Linux 本地 SDK 路徑以避開 35.0.0 corruption 問題
run {
    val properties = java.util.Properties()
    val localPropertiesFile = file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { properties.load(it) }
    }
    properties.setProperty("sdk.dir", "/home/tim/android-sdk")
    localPropertiesFile.outputStream().use { properties.store(it, "Auto-overwritten by Gradle to point to Linux local SDK") }
}

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
