package com.diasponiger.diasponiger;

import com.ryanheise.audioservice.AudioServiceFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
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
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        // Le moteur étant désormais mis en cache par audio_service, cette méthode
        // peut être appelée plusieurs fois sur le même moteur (recréation de
        // l'activité). PluginRegistry.add() ignore les doublons, l'ajout reste sûr.
        flutterEngine.getPlugins().add(new PlayIntegrityPlugin());
    }
}
