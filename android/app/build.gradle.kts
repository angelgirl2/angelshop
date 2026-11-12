import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.angelgirlbrand.angelshop"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.angelgirlbrand.angelshop"
        minSdk = flutter.minSdkVersion
        targetSdk = 36

        versionCode = 1
        versionName = "1.0.0"

        ndk {
            abiFilters += listOf(
                "arm64-v8a",
                "armeabi-v7a",
                "x86_64"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            val keystorePropertiesFile = rootProject.file("key.properties")

            if (keystorePropertiesFile.exists()) {
                val props = Properties()

                keystorePropertiesFile.inputStream().use {
                    props.load(it)
                }

                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
                storePassword = props.getProperty("storePassword")

                val storeFilePath = props.getProperty("storeFile")

                if (!storeFilePath.isNullOrBlank()) {
                    storeFile = rootProject.file(storeFilePath)
                }
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = if (rootProject.file("key.properties").exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}