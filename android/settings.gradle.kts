pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()

        file("local.properties").inputStream().use {
            properties.load(it)
        }

        val flutterSdkPath = properties.getProperty("flutter.sdk")

        require(!flutterSdkPath.isNullOrBlank()) {
            "flutter.sdk is not set in android/local.properties"
        }

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

    id("com.android.application") version "8.13.0" apply false

    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

dependencyResolutionManagement {
    repositoriesMode.set(
        org.gradle.api.initialization.resolve.RepositoriesMode.PREFER_SETTINGS
    )

    val storageUrl =
        System.getenv("FLUTTER_STORAGE_BASE_URL")
            ?: "https://storage.googleapis.com"

    repositories {
        google()
        mavenCentral()
        maven("$storageUrl/download.flutter.io")
    }
}

rootProject.name = "BrainMemory"

include(":app")