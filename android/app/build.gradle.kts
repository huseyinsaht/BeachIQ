plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.beachiq.beachiq"
    // geocoding_android (#254) requires compiling against SDK 36; Flutter 3.32's
    // own default (flutter.compileSdkVersion) is lower and fails the manifest merge.
    compileSdk = 36
    // Plugins (flutter_local_notifications, path_provider_android,
    // shared_preferences_android, url_launcher_android, integration_test)
    // require NDK 28.2; Flutter's own default is lower and warns on every build.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Required by flutter_local_notifications (#221), which needs core
        // library desugaring enabled for :app.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.beachiq.beachiq"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // geocoding_android (#254) requires minSdk 24; Flutter 3.32's own default
        // (flutter.minSdkVersion, 21) is lower and fails the manifest merge.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Required because flutter_local_notifications needs core library
    // desugaring enabled (see compileOptions above).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}
