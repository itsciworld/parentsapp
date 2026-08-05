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

// Release signing credentials live in android/key.properties, which is gitignored.
// Absent (fresh clone, CI without secrets) we fall back to debug signing below so
// `flutter build` still works — it just produces a non-publishable APK.
val keystoreProperties: Properties? = run {
    val propsFile = rootProject.file("key.properties")
    if (!propsFile.exists()) return@run null
    val props = Properties()
    propsFile.inputStream().use { props.load(it) }
    props
}

android {
    namespace = "com.app.parent.app"
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
        applicationId = "com.app.parent.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Exposes the Maps key to AndroidManifest.xml via ${MAPS_API_KEY}.
        manifestPlaceholders["MAPS_API_KEY"] = googleMapsApiKey
    }

    signingConfigs {
        if (keystoreProperties != null) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                // Resolved relative to this module (android/app/).
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
