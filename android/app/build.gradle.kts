plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.equisplit"
    compileSdk = 36  // Android 14+
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.equisplit"
        minSdk = flutter.minSdkVersion  // Android 5.0
        targetSdk = 36  // Android 14+
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            // Using debug signing for now - you can share this APK
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
