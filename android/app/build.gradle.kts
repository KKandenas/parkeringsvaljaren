import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Släppnyckeln. GitHub Actions skriver key.properties och nyckelfilen från
// repots hemligheter (se .github/workflows/apk.yml). Saknas filen signeras
// release-bygget med debugnyckeln, så att `flutter run --release` fungerar.
val nyckelFil = rootProject.file("key.properties")
val nyckel = Properties().apply {
    if (nyckelFil.exists()) nyckelFil.inputStream().use { load(it) }
}

android {
    namespace = "se.kandenas.parkeringsvaljaren"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "se.kandenas.parkeringsvaljaren"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (nyckelFil.exists()) {
            create("slapp") {
                storeFile = file(nyckel.getProperty("storeFile"))
                storePassword = nyckel.getProperty("storePassword")
                keyAlias = nyckel.getProperty("keyAlias")
                keyPassword = nyckel.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (nyckelFil.exists()) {
                signingConfigs.getByName("slapp")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
