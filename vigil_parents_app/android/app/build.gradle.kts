import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Single source of truth for the Google Maps key: read it from the project's
// .env (the same file the Dart side uses). Keeps the key out of git and out of
// the committed manifest. Injected below as the ${MAPS_API_KEY} placeholder.
val googleMapsApiKey: String = run {
    val envFile = rootProject.file("../.env")
    if (!envFile.exists()) return@run ""
    val props = Properties()
    envFile.inputStream().use { props.load(it) }
    (props.getProperty("GOOGLE_MAPS_API_KEY") ?: "").trim()
}

android {
    namespace = "com.example.vigil_parents_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications / background service.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.vigil_parents_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Exposes the Maps key to AndroidManifest.xml via ${MAPS_API_KEY}.
        manifestPlaceholders["MAPS_API_KEY"] = googleMapsApiKey
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
