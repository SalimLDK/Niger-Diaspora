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

    /** Étiquette logcat du routage des liens profonds. */
    private static final String DEEP_LINK_TAG = "DiaspoDeepLink";

    /** Canal par lequel une route reçue à chaud est remise au routeur Dart. */
    private static final String DEEP_LINK_CHANNEL = "diaspo_niger/deep_link";

    /**
     * Canal par lequel l'écran d'appel demande à s'afficher par-dessus le keyguard.
     *
     * Remplace les attributs `android:showWhenLocked` / `android:turnScreenOn` du
     * manifeste : posés là, ils valaient pour toute la vie de l'activité, donc
     * l'application entière restait consultable par-dessus l'écran de
     * verrouillage. Ici le privilège est demandé à l'ouverture de l'écran d'appel
     * et rendu à sa fermeture.
     */
    private static final String LOCKSCREEN_CHANNEL = "diaspo_niger/lockscreen";

    /** Retenu pour pouvoir émettre depuis `onNewIntent`. */
    private MethodChannel deepLinkChannel;

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
                            } else if ("getInstallationId".equals(call.method)) {
                                result.success(getInstallationId());
                            } else {
                                result.notImplemented();
                            }
                        });

        deepLinkChannel =
                new MethodChannel(
                        flutterEngine.getDartExecutor().getBinaryMessenger(), DEEP_LINK_CHANNEL);

        new MethodChannel(
                        flutterEngine.getDartExecutor().getBinaryMessenger(), LOCKSCREEN_CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if ("setShowWhenLocked".equals(call.method)) {
                                Boolean enabled = call.argument("enabled");
                                setShowOverKeyguard(Boolean.TRUE.equals(enabled));
                                result.success(null);
                            } else {
                                result.notImplemented();
                            }
                        });
    }

    /**
     * Autorise (ou retire) l'affichage par-dessus l'écran de verrouillage.
     *
     * setShowWhenLocked/setTurnScreenOn existent depuis l'API 27 ; en dessous, le
     * même effet passait par des drapeaux de fenêtre. minSdk du projet étant plus
     * bas que 27 sur le papier, on garde le repli plutôt que de ne rien faire —
     * sans quoi accepter un appel depuis le keyguard redeviendrait invisible sur
     * ces appareils.
     */
    private void setShowOverKeyguard(boolean enabled) {
        runOnUiThread(
                () -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
                        setShowWhenLocked(enabled);
                        setTurnScreenOn(enabled);
                    } else if (enabled) {
                        getWindow()
                                .addFlags(
                                        android.view.WindowManager.LayoutParams
                                                        .FLAG_SHOW_WHEN_LOCKED
                                                | android.view.WindowManager.LayoutParams
                                                        .FLAG_TURN_SCREEN_ON);
                    } else {
                        getWindow()
                                .clearFlags(
                                        android.view.WindowManager.LayoutParams
                                                        .FLAG_SHOW_WHEN_LOCKED
                                                | android.view.WindowManager.LayoutParams
                                                        .FLAG_TURN_SCREEN_ON);
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
     * Identifiant d'installation stable (SSAID), pour dériver un identifiant
     * d'appareil E2EE qui survive à un vidage de données.
     *
     * L'identifiant d'appareil était un UUID aléatoire rangé dans le stockage
     * sécurisé : perdu au moindre vidage de données, il faisait créer une
     * NOUVELLE ligne dans `e2ee_devices` à chaque régénération de clés. Les
     * entrées mortes s'accumulaient (2 → 3 le 2026-08-04), et tout message
     * envoyé au compte doit être chiffré pour chacune.
     *
     * Depuis Android 8, le SSAID est propre au triplet (clé de signature,
     * utilisateur, appareil) : il survit au vidage de données ET à une
     * réinstallation signée de la même clé, et il n'est pas partagé entre
     * applications — ce n'est donc pas un identifiant matériel.
     *
     * Il n'est jamais envoyé tel quel : le Dart en dérive un condensé salé par
     * l'identifiant de compte (cf. `stableDeviceId`).
     *
     * Peut être null sur des ROM exotiques ; l'appelant retombe alors sur un
     * UUID aléatoire, c'est-à-dire l'ancien comportement.
     */
    private String getInstallationId() {
        return android.provider.Settings.Secure.getString(
                getContentResolver(), android.provider.Settings.Secure.ANDROID_ID);
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
        // Trace conservée volontairement : sans elle, on ne peut pas distinguer
        // « onNewIntent n'a pas été appelé » de « la route n'a pas été poussée »,
        // et le diagnostic repart de zéro à chaque fois (déjà perdu une fois).
        android.util.Log.i(
                DEEP_LINK_TAG, "onNewIntent action=" + intent.getAction() + " data=" + intent.getDataString());
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

        // On remet la route au routeur Dart par un canal explicite, et NON par
        // `getNavigationChannel().pushRouteInformation(...)`.
        //
        // Vérifié sur appareil le 2026-08-04 : avec `singleTask`, `onNewIntent`
        // est bien appelé et `pushRouteInformation` bien exécuté — mais GoRouter
        // ne journalise aucune navigation. Le canal de navigation de l'embedding
        // n'aboutit pas dans ce montage (moteur mis en cache par audio_service).
        // Le canal explicite, lui, atterrit dans du code qu'on contrôle.
        if (deepLinkChannel == null) {
            android.util.Log.w(DEEP_LINK_TAG, "canal absent, route perdue : " + route);
            return;
        }
        android.util.Log.i(DEEP_LINK_TAG, "route poussee vers Dart : " + route);
        deepLinkChannel.invokeMethod("onDeepLink", route.toString());
    }
}
