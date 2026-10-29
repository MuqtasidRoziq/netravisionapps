import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.netravision.apps"
    // ultralytics_yolo (LiteRT 2.1.5) requires compileSdk 36 and minSdk 23.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.netravision.apps"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // ultralytics_yolo (LiteRT 2.1.5) declares minSdk 23.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Google Maps SDK key diambil dari file .env di root project, env sistem,
        // atau Gradle property (-P), lalu disuntik ke manifest placeholder (AndroidManifest geo.API_KEY).
        val envProperties = mutableMapOf<String, String>()
        val envFile = rootProject.projectDir.parentFile.resolve(".env")
        if (envFile.exists()) {
            envFile.forEachLine { rawLine ->
                val line = rawLine.trim()
                if (line.isNotEmpty() && !line.startsWith("#") && line.contains("=")) {
                    val parts = line.split("=", limit = 2)
                    val k = parts[0].trim()
                    val v = parts[1].trim().removeSurrounding("\"").removeSurrounding("'")
                    envProperties[k] = v
                }
            }
        }

        val mapsKey = System.getenv("GOOGLE_MAPS_API_KEY")
            ?: System.getenv("MAPS_API_KEY")
            ?: providers.gradleProperty("GOOGLE_MAPS_API_KEY").orNull
            ?: providers.gradleProperty("MAPS_API_KEY").orNull
            ?: envProperties["GOOGLE_MAPS_API_KEY"]
            ?: envProperties["MAPS_API_KEY"]
            ?: ""
        manifestPlaceholders["MAPS_API_KEY"] = mapsKey
    }

    // 2. Mendaftarkan konfigurasi signing release
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // 3. Mengambil konfigurasi release jika key.properties ada, 
            // atau fallback ke debug jika belum ada agar build tidak gagal saat development
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            
            // Keep R8 off: the 63 MB model dominates APK size, so shrinking saves little
            // while risking stripping LiteRT/JNI entry points.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    androidResources {
        noCompress += "tflite"
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// ultralytics_yolo pulls LiteRT 2.x (`com.google.ai.edge.litert:litert`), which is
// self-contained; the old litert-support-api workaround for flutter_vision is gone.

flutter {
    source = "../.."
}