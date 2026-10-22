package com.diasponiger.diagnostic_memoire;

import android.app.ActivityManager;
import android.content.Context;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Lit la mémoire Java du processus, pour que Crashlytics dise combien de tas
 * restait au moment d'un OutOfMemoryError.
 *
 * C'est un plugin, et non un canal posé dans MainActivity, parce que les
 * isolats d'arrière-plan (gestionnaire FCM, service de localisation, réponse
 * rapide) tournent dans un moteur Flutter propre, créé SANS activité :
 * `configureFlutterEngine` n'y passe jamais. En revanche chaque moteur appelle
 * GeneratedPluginRegistrant, qui enregistre les plugins du pubspec — celui-ci
 * y compris.
 */
public class DiagnosticMemoirePlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private static final String CHANNEL = "diaspo_niger/diagnostic_memoire";
    private static final long MIO = 1024L * 1024L;

    private MethodChannel channel;
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if (!"lireMemoire".equals(call.method)) {
            result.notImplemented();
            return;
        }
        try {
            Runtime rt = Runtime.getRuntime();
            Map<String, Object> m = new HashMap<>();
            m.put("tasMaxMio", rt.maxMemory() / MIO);
            m.put("tasAlloueMio", rt.totalMemory() / MIO);
            // Libre DANS la part déjà allouée ; le vrai reste avant OOM est
            // tasMax - (tasAlloue - tasLibre), calculé côté Dart.
            m.put("tasLibreMio", rt.freeMemory() / MIO);
            ActivityManager am =
                    (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
            if (am != null) {
                m.put("classeMemoireMio", am.getMemoryClass());
                m.put("largeClasseMemoireMio", am.getLargeMemoryClass());
                m.put("appareilPeuDeRam", am.isLowRamDevice());
            }
            result.success(m);
        } catch (Throwable t) {
            result.error("memoire", t.getClass().getSimpleName(), null);
        }
    }
}
