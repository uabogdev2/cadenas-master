plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.pegadev.lock_game"
    compileSdk = 36 // Changed to target Android 16 (API 36 - assumed future API level)

    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pegadev.lockgame"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 28 // Android 9 (API 28)
        targetSdk = 36 // Changed to target Android 16 (API 36 - assumed future API level)
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Configuration pour la compatibilité avec les anciennes versions d'Android
        vectorDrawables.useSupportLibrary = true
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            storeFile = file("keystore/release.keystore")
            storePassword = "android"
            keyAlias = "lock_game"
            keyPassword = "android"
        }
    }

    buildTypes {
        release {
            // Utiliser la configuration de signature de release
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            // Suppression du suffixe pour que le package name corresponde à celui dans google-services.json
            // applicationIdSuffix = ".debug"
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.7.2"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.android.gms:play-services-ads:23.0.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Support pour la rétrocompatibilité
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    
    // Note: play:core n'est pas inclus car il cause des conflits avec core-common
    // Les classes manquantes sont gérées par les règles ProGuard dans proguard-rules.pro
}

flutter {
    source = "../.."
}