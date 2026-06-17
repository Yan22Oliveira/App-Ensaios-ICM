import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

// carrega key.properties para assinatura release
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        FileInputStream(file).use { load(it) }
    }
}

android {
    namespace = "com.app.class_attendance"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.app.class.attendance"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        multiDexEnabled = true
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Só configura se o arquivo existir
            val alias = keystoreProperties["keyAlias"] as String?
            val keyPass = keystoreProperties["keyPassword"] as String?
            val storePass = keystoreProperties["storePassword"] as String?
            val storePath = keystoreProperties["storeFile"] as String?

            if (!storePath.isNullOrBlank()) {
                storeFile = file(storePath)
            }
            keyAlias = alias
            keyPassword = keyPass
            storePassword = storePass
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false // <- desliga o shrink de recursos
            signingConfig = signingConfigs.getByName("release")
        }

        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

}

flutter {
    source = "../.."
}

dependencies {
    // Multidex (use AndroidX)
    implementation("androidx.multidex:multidex:2.0.1")

    // Play install referrer (se necessário)
    implementation("com.android.installreferrer:installreferrer:2.2")

    // Desugaring libs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}