package com.diasponiger.diasponiger;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.WindowManager;

import com.ryanheise.audioservice.AudioServiceFragmentActivity;
import com.ryanheise.audioservice.AudioServicePlugin;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
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

    /** Canal de la luminosité d'écran (affichage d'un QR à faire scanner). */
    private static final String SCREEN_CHANNEL = "diaspo_niger/screen";

    /** Retenu pour pouvoir émettre depuis `onNewIntent`. */
    private MethodChannel deepLinkChannel;

    /**
     * Moteur courant, retenu pour `onNewIntent`. Réaffecté à chaque
     * rattachement — le moteur étant mis en cache par audio_service, il survit
     * à l'activité, mais la référence doit rester celle qu'on nous passe.
     */
    private FlutterEngine flutterEngine;

    /**
     * Route d'un lien pas encore remise au routeur Dart.
     *
     * Posee quand le canal n'existe pas encore (le fragment Flutter s'attache par
     * une transaction asynchrone, donc `configureFlutterEngine` peut tourner
     * APRES `onCreate`), ou quand le Dart n'a pas encore branche son ecoute
     * (moteur tout juste cree par `AudioService`). Videe des que la remise
     * aboutit, ou quand le Dart la reclame par `takePendingLink`.
     */
    private String routeEnAttente;

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
        // Le Dart reclame ici, en branchant son ecoute, une route qu'on n'a pas
        // pu lui remettre faute d'ecoute (cf. `remettreRoute`).
        deepLinkChannel.setMethodCallHandler(
                (call, result) -> {
                    if ("takePendingLink".equals(call.method)) {
                        String route = routeEnAttente;
                        routeEnAttente = null;
                        result.success(route);
                    } else {
                        result.notImplemented();
                    }
                });
        // Route posee par `onCreate` avant que ce canal n'existe.
        if (routeEnAttente != null) {
            remettreRoute(routeEnAttente);
        }

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

        new MethodChannel(
                        flutterEngine.getDartExecutor().getBinaryMessenger(), SCREEN_CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if ("setMaxBrightness".equals(call.method)) {
                                Boolean enabled = call.argument("enabled");
                                setMaxBrightness(Boolean.TRUE.equals(enabled));
                                result.success(null);
                            } else {
                                result.notImplemented();
                            }
                        });
    }

    /**
     * Pousse la luminosité au maximum, ou rend la main au réglage système.
     *
     * Porté par la fenêtre de l'activité, pas par les réglages de l'appareil :
     * rien n'est modifié durablement, et l'effet disparaît de lui-même si
     * l'activité meurt sans que Dart ait pu rétablir quoi que ce soit.
     * BRIGHTNESS_OVERRIDE_NONE (-1) est la valeur qui signifie « laisse le
     * système décider », pas « éteins l'écran ».
     */
    private void setMaxBrightness(boolean enabled) {
        runOnUiThread(
                () -> {
                    WindowManager.LayoutParams params = getWindow().getAttributes();
                    params.screenBrightness =
                            enabled
                                    ? 1.0f
                                    : WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE;
                    getWindow().setAttributes(params);
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
     * Rejoue le lien d'une activite NEUVE qui se rattache a un moteur deja lance.
     *
     * Le moteur est mis en cache par audio_service et survit a l'activite. Deux
     * consequences, lues dans les sources (Flutter 3.29, audio_service 0.18.19) :
     * - l'embedding ne lit JAMAIS la route de l'intent sur un moteur en cache :
     *   `doInitialFlutterViewRun()` sort des sa premiere ligne ("Don't attempt to
     *   start a FlutterEngine if we're using a cached FlutterEngine") ;
     * - audio_service ne la lit qu'une fois, a la creation du moteur
     *   (`AudioServicePlugin.getFlutterEngine`). Si le moteur existe deja - cree
     *   par une activite precedente, ou par `AudioService` sans intent, donc avec
     *   la route "/" - la route du nouveau lien est ignoree.
     *
     * Et `onNewIntent` n'est appele que sur une instance existante. Le lien etait
     * donc perdu, l'app se rouvrant sur son dernier ecran. Reproduit sur SM A515F
     * le 2026-09-11 (lien envoye avec --activity-clear-task) : meme processus
     * avant et apres, activite neuve affichee en 397 ms, aucune trace
     * `onNewIntent`, et l'accueil au lieu du groupe.
     *
     * Chez un utilisateur : Android 11 et moins (le retour ferme l'activite sans
     * tuer le processus), la tache balayee des recents pendant que le partage de
     * position garde le processus au premier plan, ou le service audio demarre
     * par le systeme avant l'app.
     *
     * Le moteur est mesure AVANT `super.onCreate`, qui l'obtient ou le cree : s'il
     * est cree ici, audio_service a deja pris la route de l'intent, et la rejouer
     * ferait naviguer deux fois. `savedInstanceState` non nul signale une
     * recreation (rotation, retour de processus) : l'intent a deja servi.
     */
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        FlutterEngine moteurExistant =
                FlutterEngineCache.getInstance().get(AudioServicePlugin.getFlutterEngineId());
        boolean moteurDejaLance =
                moteurExistant != null && moteurExistant.getDartExecutor().isExecutingDart();
        super.onCreate(savedInstanceState);
        if (moteurDejaLance && savedInstanceState == null) {
            android.util.Log.i(
                    DEEP_LINK_TAG,
                    "activite neuve sur moteur deja lance, data=" + getIntent().getDataString());
            pushRouteFromIntent(getIntent());
        }
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
        String host = data.getHost();
        String scheme = data.getScheme();

        // Un schéma maison (diasponiger://groups/<id>) porte la SECTION dans
        // l'hôte et l'identifiant dans le chemin. Ne garder que le chemin
        // poussait « /<id> », une route qui n'existe pas : l'app tombait sur
        // « Page Not Found ». On recolle donc l'hôte devant.
        //
        // Pour un lien https, l'hôte est le domaine et ne doit surtout pas
        // être recollé : d'où le test sur le schéma.
        // Vérifié SM A515F le 2026-09-09.
        boolean schemaMaison = scheme != null && !scheme.startsWith("http");

        StringBuilder route = new StringBuilder();
        if (schemaMaison && host != null && !host.isEmpty()) {
            route.append('/').append(host);
        }
        if (path != null) route.append(path);
        if (route.length() == 0) return;
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
        remettreRoute(route.toString());
    }

    /**
     * Remet une route au routeur Dart, ou la garde si personne ne peut la recevoir.
     *
     * Canal absent (activite pas encore attachee) : gardee, `configureFlutterEngine`
     * la remettra. Ecoute Dart absente (`notImplemented`) : gardee, le Dart la
     * reclamera par `takePendingLink` en se branchant. Avant ce correctif, le
     * premier cas perdait la route en silence ("canal absent, route perdue").
     */
    private void remettreRoute(String route) {
        routeEnAttente = route;
        if (deepLinkChannel == null) {
            android.util.Log.i(DEEP_LINK_TAG, "canal pas encore pret, route gardee : " + route);
            return;
        }
        android.util.Log.i(DEEP_LINK_TAG, "route poussee vers Dart : " + route);
        deepLinkChannel.invokeMethod(
                "onDeepLink",
                route,
                new MethodChannel.Result() {
                    @Override
                    public void success(Object reponse) {
                        if (route.equals(routeEnAttente)) routeEnAttente = null;
                    }

                    @Override
                    public void error(String code, String message, Object details) {
                        android.util.Log.w(DEEP_LINK_TAG, "remise en erreur, route gardee : " + code);
                    }

                    @Override
                    public void notImplemented() {
                        android.util.Log.i(DEEP_LINK_TAG, "ecoute Dart absente, route gardee : " + route);
                    }
                });
    }
}
