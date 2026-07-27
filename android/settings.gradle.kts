pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // Permet à Gradle de télécharger lui-même le JDK réclamé par une toolchain.
    // Certains plugins (flutter_callkit_incoming) exigent `languageVersion=17`,
    // absent des JDK installés sur les postes (8 / 21 / 23). Sans ce résolveur,
    // le build échoue sur « No locally installed toolchains match » dès que le
    // JDK 17 auto-provisionné n'est plus dans le cache Gradle.
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.8.0"
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version "4.3.15" apply false
    // END: FlutterFire Configuration
}

include(":app")
