buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Google Services plugin - Versión más reciente 2025
        classpath("com.google.gms:google-services:4.4.4")
        // Dagger Hilt (requerido por SDK Izipay)
        classpath("com.google.dagger:hilt-android-gradle-plugin:2.56.2")
    }
    // Forzar JavaPoet 1.13.0 para evitar conflicto con databinding-compiler-common
    // que trae 1.10.0 (sin método canonicalName()) via Flutter Gradle plugin
    configurations.all {
        resolutionStrategy {
            force("com.squareup:javapoet:1.13.0")
        }
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // Repositorio local para archivos .aar del SDK Izipay
        flatDir {
            dirs("${rootProject.projectDir}/app/libs")
        }
    }
}

// ==================== FORZAR JAVA 11 GLOBALMENTE ====================
// Configurar Java para TODO el proyecto y dependencias
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_11.toString()
        targetCompatibility = JavaVersion.VERSION_11.toString()
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "11"
        }
    }

    // Forzar JavaPoet 1.13.0 en todos los subproyectos
    configurations.all {
        resolutionStrategy {
            force("com.squareup:javapoet:1.13.0")
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
