import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Sürüm imzası depo dışındadır (docs/ANDROID_PLANI.md §4.8). Yol BUP_IMZA ile
// verilebilir; yoksa kullanıcı klasöründeki varsayılan. Anahtar yoksa sürüm
// derlemesi durur: hata ayıklama anahtarıyla imzalı sürüm hiçbir koşulda çıkmaz.
val imzaDosyasi = file(
    System.getenv("BUP_IMZA")
        ?: "${System.getProperty("user.home")}/.bup-sanal-pos/imza/key.properties",
)
val imza = Properties().apply {
    if (imzaDosyasi.isFile) imzaDosyasi.inputStream().use { load(it) }
}

android {
    namespace = "com.bup.sanalpos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // MainActivity, ekran korumasını BuildConfig.DEBUG ile ayırır.
    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // Kurulduktan sonra değiştirilemez: değişirse telefonda ayrı uygulama olur.
        applicationId = "com.bup.sanalpos"
        // Android 9: Keystore'da "cihaz kilidi açıkken" anahtar koşulu (API 28).
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        if (imza.isNotEmpty()) {
            create("surum") {
                storeFile = file(imza.getProperty("storeFile"))
                storePassword = imza.getProperty("storePassword")
                keyAlias = imza.getProperty("keyAlias")
                keyPassword = imza.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("surum")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Dağıtılan sürüm yalnız telefon işlemcileri (ARM) içindir; x86_64 yalnız
            // emülatörde (hata ayıklama derlemesi) kullanılır. ML Kit modeli ABI
            // başınadır: APK ~90 → ~60 MB.
            // Flutter eklentisi varsayılan (x86_64 dahil) listeyi önceden koyar: temizlenir.
            ndk {
                abiFilters.clear()
                abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a"))
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val surum = allTasks.any { it.name.contains("Release") && it.project == project }
    if (surum && imza.isEmpty()) {
        throw GradleException(
            "Sürüm imza anahtarı bulunamadı: $imzaDosyasi. " +
                "Hata ayıklama anahtarıyla sürüm derlenmez (docs/ANDROID_PLANI.md).",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Parmak izi/yüz penceresi (Google, AndroidX). Sürüm sabit.
    implementation("androidx.biometric:biometric:1.1.0")
    // integration_test (yalnız geliştirme) eski androidx.test 1.2 ister; o sürümün
    // etkinlikleri Android 12+ manifest kuralına uymaz. Aynı kuşaktan güncel
    // sürümler zorlanır; kısıt bağımlılık eklemez, sürüm derlemesine test girmez.
    constraints {
        implementation("androidx.test:runner:1.6.2")
        implementation("androidx.test:rules:1.6.1")
        implementation("androidx.test:core:1.6.1")
        implementation("androidx.test:monitor:1.7.2")
        implementation("androidx.test.espresso:espresso-core:3.6.1")
    }
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    // Rota çekirdeği (saf Kotlin) JVM birim testleri: docs/ROTA_MIMARI.md §7.
    testImplementation("junit:junit:4.13.2")
}
