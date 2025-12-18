plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

import java.util.Base64
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

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
        isCoreLibraryDesugaringEnabled = true
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
                    // Only add valid Java identifiers (no dots or special characters)
                    val fieldName = pair[0].replace(".", "_").replace("-", "_")
                    if (fieldName.matches(Regex("^[a-zA-Z_][a-zA-Z0-9_]*$"))) {
                        buildConfigField("String", fieldName, "\"${pair[1]}\"")
                    }
                }
            }
        }
    }

    signingConfigs {
        getByName("debug") {
            keyAlias = "androiddebugkey"
            keyPassword = "android"
            storeFile = file("keystore/debug.keystore")
            storePassword = "android"
        }
        // Only create release signing config if key.properties exists with all required fields
        if (keystorePropertiesFile.exists() && 
            keystoreProperties["keyAlias"] != null &&
            keystoreProperties["keyPassword"] != null &&
            keystoreProperties["storeFile"] != null &&
            keystoreProperties["storePassword"] != null) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
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
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            if (signingConfigs.findByName("release") != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
