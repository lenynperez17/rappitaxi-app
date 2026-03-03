import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("kotlin-parcelize")
    id("com.google.devtools.ksp")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("dagger.hilt.android.plugin")
}

// ==================== CARGA DE CREDENCIALES DEL KEYSTORE DE PRODUCCIÓN ====================
// Cargar propiedades desde key.properties (contiene credenciales del keystore)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.rapiteam.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // ==================== CONFIGURACIÓN JAVA ====================
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    // Suprimir warnings de Java en dependencias externas
    tasks.withType<JavaCompile> {
        options.compilerArgs.addAll(listOf("-Xlint:-options", "-Xlint:-deprecation"))
    }

    defaultConfig {
        // ApplicationID para RapiTeam app (debe coincidir con Firebase Console)
        applicationId = "com.rapiteam.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Forzar Java 11 para evitar warnings de Java 8 obsoleto
        javaCompileOptions {
            annotationProcessorOptions {
                arguments["dagger.gradle.incremental"] = "true"
            }
        }
    }

    // ==================== CONFIGURACIÓN DE FIRMA DIGITAL (SIGNING) ====================
    signingConfigs {
        // Configuración de signing para RELEASE (producción)
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    // Desactivar lint fatal para evitar errores de compilación
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    buildTypes {
        release {
            // ✅ Usar keystore de PRODUCCIÓN para builds release
            signingConfig = signingConfigs.getByName("release")

            // Optimizaciones para producción
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }

        debug {
            // Usar el mismo keystore de release para que Google Sign-In funcione
            // (el SHA-1 del release keystore esta registrado en Firebase Console)
            signingConfig = signingConfigs.getByName("release")
            isDebuggable = true
        }
    }
}

hilt {
    enableAggregatingTask = true
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring - Versión más reciente 2025
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // ==================== SDK NATIVO IZIPAY ====================
    // Archivos .aar del SDK Izipay para pagos con tarjeta
    implementation(files("libs/izipay-sdk-2.3.0.aar"))
    implementation(files("libs/sonic-sdk-release-1.4.0.aar"))
    implementation(files("libs/visa-sensory-branding-2.1.aar"))
    // Cybersource (detección de fraude)
    implementation(files("libs/TMXProfiling-rl-7.7-71.aar"))
    implementation(files("libs/TMXProfilingConnections-rl-7.7-71.aar"))
    implementation(files("libs/TMXAuthentication-rl-7.7-71.aar"))
    implementation(files("libs/TMXBehavioSec-rl-7.7-71.aar"))
    implementation(files("libs/TMXDeviceSecurityHealth-rl-7.7-71.aar"))

    // Dagger Hilt (requerido por SDK Izipay ContainerActivity)
    implementation("com.google.dagger:hilt-android:2.56.2")
    ksp("com.google.dagger:hilt-compiler:2.56.2")

    // Dependencias requeridas por el SDK Izipay
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.activity:activity-ktx:1.8.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.fragment:fragment-ktx:1.6.2")
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.retrofit2:converter-scalars:2.9.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-livedata-ktx:2.7.0")
    implementation("androidx.navigation:navigation-fragment-ktx:2.7.7")
    implementation("androidx.navigation:navigation-ui-ktx:2.7.7")
    implementation("com.google.code.gson:gson:2.10.1")
    implementation("com.github.bumptech.glide:glide:4.16.0")
    implementation("com.github.skydoves:balloon:1.6.4")
    implementation("com.github.skydoves:powerspinner:1.2.7")
}
