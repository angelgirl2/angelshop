import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

val releaseKeystoreFile = rootProject.file("key.properties")
val useReleaseSigning = releaseKeystoreFile.exists() &&
    System.getenv("ANGELSHOP_CI_DEBUG_SIGNING") != "true"

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

    signingConfigs {
        create("release") {
            val keystorePropertiesFile = releaseKeystoreFile

            if (useReleaseSigning) {
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
            signingConfig = if (useReleaseSigning)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}