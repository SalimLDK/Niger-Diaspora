package com.diasponiger.diasponiger;

import android.content.Intent;

import com.ryanheise.audioservice.AudioServiceFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import androidx.annotation.NonNull;

/**
 * Activité principale.
 *
 * Étend AudioServiceFragmentActivity (et non FlutterFragmentActivity directement)
 * parce qu'audio_service exige de fournir LUI-MÊME le FlutterEngine : il en garde
 * un en cache, partagé entre l'activité et le service de lecture en arrière-plan,
 * et qui survit à la destruction de l'activité. Sans ça, AudioService.init() échoue
 * au démarrage avec « The Activity class declared in your AndroidManifest.xml is
 * wrong or has not provided the correct FlutterEngine », et la lecture de podcasts
 * en arrière-plan ne fonctionne pas.
 *
 * AudioServiceFragmentActivity étend elle-même FlutterFragmentActivity : le
 * comportement attendu par les autres plugins est préservé.
 */
public class MainActivity extends AudioServiceFragmentActivity {

    /** Canal appelé par SharedMediaService une fois le partage présenté. */
    private static final String SHARE_INTENT_CHANNEL = "diaspo_niger/share_intent";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        // Le moteur étant désormais mis en cache par audio_service, cette méthode
        // peut être appelée plusieurs fois sur le même moteur (recréation de
        // l'activité). PluginRegistry.add() ignore les doublons, l'ajout reste sûr.
        flutterEngine.getPlugins().add(new PlayIntegrityPlugin());

        // Réenregistré à chaque appel, donc toujours lié à l'instance d'activité
        // courante : après une recréation, l'ancienne ne doit plus recevoir.
        new MethodChannel(
                        flutterEngine.getDartExecutor().getBinaryMessenger(),
                        SHARE_INTENT_CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if ("clearSharedIntent".equals(call.method)) {
                                clearSharedIntent();
                                result.success(null);
                            } else {
                                result.notImplemented();
                            }
                        });
    }

    /**
     * Remplace l'intent de partage porté par l'activité par un ACTION_MAIN neutre.
     *
     * receive_sharing_intent relit `activity.getIntent()` à chaque rattachement au
     * moteur Flutter : sans ce nettoyage, une rotation ou un retour depuis les
     * récents rouvrait la feuille « Envoyer à… » sur un partage déjà traité.
     *
     * Ne couvre PAS le redémarrage complet du process : l'intent d'origine de la
     * tâche est conservé par le système, hors de portée de l'application. Ce cas
     * est traité côté Dart par l'empreinte persistée du dernier partage présenté.
     */
    private void clearSharedIntent() {
        setIntent(new Intent(Intent.ACTION_MAIN));
    }
}
