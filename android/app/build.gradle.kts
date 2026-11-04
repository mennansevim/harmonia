import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (REL-09): android/key.properties is local-only (gitignored)
// with storeFile, storePassword, keyAlias, keyPassword. Without it, release
// tasks fail closed unless the explicit local-only debug-signing override is set.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val releaseKeyFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val releaseStorePath = keystoreProperties.getProperty("storeFile")
val hasReleaseKey =
    releaseKeyFields.all { !keystoreProperties.getProperty(it).isNullOrBlank() } &&
        releaseStorePath != null && rootProject.file(releaseStorePath).isFile
val allowDebugReleaseSigning =
    providers.gradleProperty("allowDebugReleaseSigning").orNull == "true"
val releaseTaskRequested =
    gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }

android {
    namespace = "com.mennansevim.vocalart"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Store ID is final once published; confirm before the first upload.
        applicationId = "com.mennansevim.vocalart"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                if (releaseTaskRequested && !allowDebugReleaseSigning) {
                    throw GradleException(
                        "Vocalart release imzasi hazir degil: android/key.properties " +
                            "ve gecerli keystore gerekli. Yalniz yerel build kaniti icin " +
                            "-PallowDebugReleaseSigning=true acikca verilebilir; bu cikti " +
                            "magazaya yuklenemez.",
                    )
                }
                if (allowDebugReleaseSigning) {
                    logger.warn(
                        "Vocalart: explicit local override ile release DEBUG anahtariyla " +
                            "imzalaniyor; magazaya yuklenemez.",
                    )
                }
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
