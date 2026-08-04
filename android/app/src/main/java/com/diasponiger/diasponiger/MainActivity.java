package com.diasponiger.diasponiger;

import android.content.Intent;
import android.net.Uri;

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

    /**
     * Moteur courant, retenu pour `onNewIntent`. Réaffecté à chaque
     * rattachement — le moteur étant mis en cache par audio_service, il survit
     * à l'activité, mais la référence doit rester celle qu'on nous passe.
     */
    private FlutterEngine flutterEngine;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        this.flutterEngine = flutterEngine;
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

    /**
     * Transmet à Flutter les liens reçus alors que l'application tourne déjà.
     *
     * `flutter_deeplinking_enabled` ne couvre que le démarrage : vérifié sur
     * appareil le 2026-08-04, un lien ouvert avec l'app en arrière-plan était
     * bien délivré ici (« intent has been delivered to currently running
     * top-most instance ») mais n'atteignait jamais GoRouter — aucune
     * navigation, l'app revenait simplement au premier plan sur l'écran quitté.
     *
     * En cause, le moteur mis en cache qu'impose audio_service : l'embedding
     * Flutter ne relaie pas les nouveaux intents au canal de navigation dans ce
     * montage. On pousse donc la route nous-mêmes, exactement comme le fait
     * l'embedding au démarrage — chemin + requête + fragment, sans le schéma ni
     * l'hôte, que GoRouter n'attend pas.
     */
    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        pushRouteFromIntent(intent);
    }

    private void pushRouteFromIntent(Intent intent) {
        if (!Intent.ACTION_VIEW.equals(intent.getAction())) return;
        Uri data = intent.getData();
        if (data == null) return;

        String path = data.getPath();
        // Un schéma custom (diasponiger://feed/<id>) porte « feed » dans l'hôte
        // et non dans le chemin : il n'y a alors rien de routable à pousser.
        if (path == null || path.isEmpty()) return;

        StringBuilder route = new StringBuilder(path);
        if (data.getQuery() != null) route.append('?').append(data.getQuery());
        if (data.getFragment() != null) route.append('#').append(data.getFragment());

        if (flutterEngine == null) return;
        flutterEngine.getNavigationChannel().pushRouteInformation(route.toString());
    }
}
