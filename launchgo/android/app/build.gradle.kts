plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Base64

android {
    namespace = "com.launchgo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.launchgo.stage"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Pass dart-define variables to Android
        val dartDefines = project.findProperty("dart-defines") as String? ?: ""
        if (dartDefines.isNotEmpty()) {
            val decodedDefines = dartDefines.split(",").map { encoded ->
                String(Base64.getDecoder().decode(encoded))
            }
            decodedDefines.forEach { define ->
                val pair = define.split("=", limit = 2)
                if (pair.size == 2) {
                    buildConfigField("String", pair[0], "\"${pair[1]}\"")
                }
            }
        }
    }

    flavorDimensions += "environment"
    productFlavors {
        create("stage") {
            dimension = "environment"
            applicationId = "com.launchgo.stage"
            versionNameSuffix = "-stage"
        }
        create("prod") {
            dimension = "environment"
            applicationId = "com.launchgo.app"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
