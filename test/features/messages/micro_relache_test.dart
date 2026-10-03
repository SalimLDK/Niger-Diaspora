import 'dart:async';
import 'dart:io';

import 'package:diaspo_niger/core/services/audio_recording_service.dart';
import 'package:diaspo_niger/core/services/preferences_service.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/message_input.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Le micro du composeur, quand le doigt va plus vite que lui.
///
/// `_startRecording` attend la permission, puis le démarrage du micro. Un
/// doigt levé pendant l'une ou l'autre trouvait `_isRecording` encore à faux :
/// `onLongPressEnd` ne faisait rien, puis l'enregistrement démarrait — et plus
/// rien ne l'arrêtait. Et l'app passée en arrière-plan pendant l'appui laissait
/// le micro ouvert, `onLongPressEnd` ne venant jamais.
void main() {
  late _Micro micro;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.initialize();
    micro = _Micro();
    AudioRecordingService.remplacantPourTests = micro;
  });

  tearDown(() => AudioRecordingService.remplacantPourTests = null);

  Future<void> monter(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(
          body: MessageInput(
            conversationId: 'conv-test',
            onSendText: (_, __) {},
            onSendFile: (File file, MessageType type, {String? caption}) {},
            onSendAudio: (_, __, ___) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder boutonMicro() => find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onLongPressStart != null,
      );

  Future<TestGesture> appuyerLonguement(WidgetTester tester) async {
    final geste =
        await tester.startGesture(tester.getCenter(boutonMicro()));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    return geste;
  }

  testWidgets('relâché pendant la demande de permission : rien ne démarre',
      (tester) async {
    await monter(tester);
    micro.permission = Completer<bool>();

    final geste = await appuyerLonguement(tester);
    await geste.up();
    await tester.pump();
    micro.permission!.complete(true);
    await tester.pump();

    expect(micro.demarrages, 0);
  });

  testWidgets('relâché pendant le démarrage du micro : annulé aussitôt',
      (tester) async {
    await monter(tester);
    micro.demarrage = Completer<String?>();

    final geste = await appuyerLonguement(tester);
    await tester.pump();
    expect(micro.demarrages, 1);
    await geste.up();
    await tester.pump();
    micro.demarrage!.complete('/tmp/vocal.m4a');
    await tester.pump();

    expect(micro.annulations, 1,
        reason: 'sinon personne n\'arrête cet enregistrement');
    expect(micro.arrets, 0);
  });

  testWidgets('app en arrière-plan pendant l\'appui : le micro est coupé',
      (tester) async {
    await monter(tester);

    final geste = await appuyerLonguement(tester);
    await tester.pump();
    expect(micro.demarrages, 1);

    for (final etat in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(etat);
    }
    await tester.pump();

    expect(micro.annulations, 1);
    await geste.up();
    await tester.pump();
    expect(micro.arrets, 0, reason: 'rien n\'est envoyé après coup');
    for (final etat in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(etat);
    }
  });

  testWidgets('témoin : maintenir puis relâcher envoie le vocal',
      (tester) async {
    await monter(tester);

    final geste = await appuyerLonguement(tester);
    await tester.pump();
    await geste.up();
    await tester.pump();

    expect(micro.arrets, 1);
    expect(micro.annulations, 0);
  });
}

class _Micro implements AudioRecordingService {
  Completer<bool>? permission;
  Completer<String?>? demarrage;
  int demarrages = 0;
  int annulations = 0;
  int arrets = 0;

  @override
  Future<bool> requestPermission() => permission?.future ?? Future.value(true);

  @override
  Future<String?> startRecording() {
    demarrages++;
    return demarrage?.future ?? Future.value('/tmp/vocal.m4a');
  }

  @override
  Future<void> cancelRecording() async => annulations++;

  @override
  Future<(File, int, List<double>)?> stopRecording() async {
    arrets++;
    return null;
  }

  @override
  Stream<int> get durationStream => const Stream.empty();

  @override
  Stream<double> get amplitudeStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
