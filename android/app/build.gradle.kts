import java.net.URI
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

val signingValues = Properties()
val signingFile = rootProject.file("key.properties")
if (signingFile.exists()) signingFile.inputStream().use { signingValues.load(it) }
val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseRequested) {
    val defines = (project.findProperty("dart-defines") as String? ?: "").split(",")
        .mapNotNull {
            runCatching {
                String(Base64.getDecoder().decode(it), Charsets.UTF_8)
            }.getOrNull()
        }
    val endpoint = defines.firstOrNull { it.startsWith("API_BASE_URL=") }
        ?.substringAfter("=") ?: ""
    val address = runCatching { URI(endpoint) }.getOrNull()
    if (
        address == null || address.scheme != "https" || address.host.isNullOrBlank() ||
        address.host in listOf("localhost", "127.0.0.1", "10.0.2.2") ||
        address.userInfo != null || address.query != null || address.fragment != null
    ) {
        throw GradleException("Release exige --dart-define=API_BASE_URL=https://DOMINIO_DA_API.")
    }
}
if (releaseRequested && !signingFile.exists()) {
    throw GradleException("Configure android/key.properties privado antes de gerar release.")
}
val requiredSigningFields = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
if (releaseRequested && requiredSigningFields.any { signingValues.getProperty(it).isNullOrBlank() }) {
    throw GradleException("Preencha todos os campos privados de android/key.properties antes de gerar release.")
}

android {
    namespace = "com.zeresolve.ze_resolve"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.zeresolve.ze_resolve"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingFile.exists()) {
            create("production") {
                keyAlias = signingValues.getProperty("keyAlias")
                keyPassword = signingValues.getProperty("keyPassword")
                storeFile = file(signingValues.getProperty("storeFile"))
                storePassword = signingValues.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (signingFile.exists()) signingConfig = signingConfigs.getByName("production")
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
