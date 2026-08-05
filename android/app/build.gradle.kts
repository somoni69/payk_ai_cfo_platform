import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningProperties = Properties()
val releaseSigningFile = rootProject.file("key.properties")
if (releaseSigningFile.exists()) {
    releaseSigningFile.inputStream().use { input ->
        releaseSigningProperties.load(input)
    }
}
val releaseSigningKeys = listOf(
    "keyAlias",
    "keyPassword",
    "storeFile",
    "storePassword",
)
val releaseStoreFile = releaseSigningProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let(::file)
val hasReleaseSigning =
    releaseSigningFile.exists() &&
        releaseSigningKeys.all {
            !releaseSigningProperties.getProperty(it).isNullOrBlank()
        } &&
        releaseStoreFile?.isFile == true

val applicationIdValue = providers.gradleProperty("paykApplicationId")
    .orElse(providers.environmentVariable("PAYK_APPLICATION_ID"))
    .orElse("com.example.payk_ai_cfo_platform")
    .get()
val allowUnsafeRelease =
    providers.gradleProperty("allowUnsafeRelease").orNull == "true"
val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseRequested && !allowUnsafeRelease) {
    check(hasReleaseSigning) {
        "Release signing is not configured. Copy key.properties.example to " +
            "key.properties and provide the production keystore values."
    }
    check(!applicationIdValue.startsWith("com.example.")) {
        "Production application ID is required. Pass " +
            "-PpaykApplicationId=<your immutable application id>."
    }
}

android {
    namespace = "com.example.payk_ai_cfo_platform"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = applicationIdValue
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
                storeFile = releaseStoreFile
                storePassword =
                    releaseSigningProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (hasReleaseSigning) "release" else "debug",
            )
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
