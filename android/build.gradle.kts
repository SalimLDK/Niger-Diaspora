allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Alignement 16 Ko des bibliotheques natives (exige par Google Play des que
// l'app cible l'API 35+). Deux dependances transitives de plugins livraient
// encore des .so alignes sur 4 Ko : le depot est refuse en Play Console, sans
// qu'aucune etape locale — compilation, installation, `flutter analyze` —
// ne signale quoi que ce soit. Verifier avec :
//     python tools/verifie_alignement_16k.py build/app/outputs/bundle/release/app-release.aab
subprojects {
    configurations.all {
        resolutionStrategy {
            // mobile_scanner 5.2.3 epingle `com.google.mlkit:barcode-scanning:17.2.0`,
            // dont libbarhopper_v3.so est aligne sur 4 Ko. La 17.3.0 est alignee
            // sur 16 Ko et garde la meme API (meme minSdk 21 que l'app).
            // A retirer quand mobile_scanner sera monte en 6.x/7.x.
            force("com.google.mlkit:barcode-scanning:17.3.0")

            dependencySubstitution {
                // livekit_client 2.4.1 depend de `com.github.paramsen:noise:2.0.0`
                // (JitPack, abandonne, libnoise.so aligne sur 4 Ko). LiveKit a
                // republie ce meme artefact sur Maven Central sous `io.livekit:noise`,
                // recompile en 16 Ko : memes classes, meme package
                // `com.paramsen.noise`, donc rien a changer dans le plugin.
                // C'est ce que livekit_client utilise lui-meme depuis la 2.5.0.
                substitute(module("com.github.paramsen:noise"))
                    .using(module("io.livekit:noise:2.0.0"))
                    .because("libnoise.so aligne sur 16 Ko (exigence Play API 35+)")
            }
        }
    }
}

// Force Java 11 pour tous les sous-projets (plugins inclus)
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_11
                    targetCompatibility = JavaVersion.VERSION_11
                }
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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


