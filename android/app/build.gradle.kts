import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (Play Store upload key). Values come from android/key.properties
// (git-ignored; keys storeFile, storePassword, keyAlias, keyPassword) or, in CI, from the
// BEACHIQ_KEYSTORE_PATH / BEACHIQ_KEYSTORE_PASSWORD / BEACHIQ_KEY_ALIAS / BEACHIQ_KEY_PASSWORD
// environment variables. Without them release builds fall back to the debug key so
// `flutter run --release` keeps working locally; such a build is NOT uploadable to Play.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(property: String, envVar: String): String? =
    keystoreProperties.getProperty(property) ?: System.getenv(envVar)

val releaseStoreFile = signingValue("storeFile", "BEACHIQ_KEYSTORE_PATH")

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

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = signingValue("storePassword", "BEACHIQ_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "BEACHIQ_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "BEACHIQ_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
