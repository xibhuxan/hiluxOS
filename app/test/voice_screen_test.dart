// ignore_for_file: avoid_relative_lib_imports
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/voice/voice_provider.dart';
import '../lib/features/voice/voice_screen.dart';

/// Fake notifier (no network / no audio) — same pattern as weather_screen_test.
class _FakeVoiceNotifier extends VoiceNotifier {
  _FakeVoiceNotifier() : super(ApiClient(Dio()));

  bool refreshCalled = false;
  String? lastText;
  int pushToTalkCalls = 0;
  int speakCalls = 0;

  void setState(VoiceState s) => state = s;

  @override
  Future<void> refresh() async {
    refreshCalled = true;
  }

  @override
  Future<void> sendText(String text) async {
    lastText = text;
    state = state.copyWith(history: [
      ...state.history,
      VoiceTurn(
          utterance: text,
          intent: 'help',
          reply: 'Respuesta de prueba',
          acted: true,
          at: 0),
    ]);
  }

  @override
  Future<void> pushToTalk(Uint8List pcm) async {
    pushToTalkCalls++;
  }

  @override
  Future<void> speakReply(String text) async {
    speakCalls++;
  }
}

VoiceState _idleState() => const VoiceState(
      loading: false,
      asrAvailable: true,
      ttsAvailable: true,
      backendReachable: true,
      history: [],
    );

VoiceState _withHistory() => const VoiceState(
      loading: false,
      asrAvailable: true,
      ttsAvailable: true,
      backendReachable: true,
      history: [
        VoiceTurn(
            utterance: 'qué tiempo hace',
            intent: 'weather',
            reply: 'Consultando el tiempo actual.',
            acted: true,
            at: 1),
        VoiceTurn(
            utterance: 'quiero ir',
            intent: 'navigate',
            reply: '¿A dónde quieres ir?',
            acted: false,
            at: 2),
      ],
    );

void main() {
  void bigViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  ProviderContainer containerWith(VoiceState s, [_FakeVoiceNotifier? fake]) {
    final f = fake ?? _FakeVoiceNotifier();
    f.setState(s);
    return ProviderContainer(overrides: [voiceProvider.overrideWith((ref) => f)]);
  }

  Future<void> pump(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: VoiceScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows loading spinner while loading', (tester) async {
    bigViewport(tester);
    final container = containerWith(const VoiceState(loading: true));
    await pump(tester, container);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    container.dispose();
  });

  testWidgets('shows the empty-state prompt when there is no history', (tester) async {
    bigViewport(tester);
    final container = containerWith(_idleState());
    await pump(tester, container);
    expect(find.text('¿En qué te ayudo?'), findsOneWidget);
    container.dispose();
  });

  testWidgets('renders the conversation history', (tester) async {
    bigViewport(tester);
    final container = containerWith(_withHistory());
    await pump(tester, container);
    expect(find.text('qué tiempo hace'), findsOneWidget);
    expect(find.text('Consultando el tiempo actual.'), findsOneWidget);
    expect(find.text('¿A dónde quieres ir?'), findsOneWidget);
    container.dispose();
  });

  testWidgets('shows the mic-unavailable banner when ASR is off', (tester) async {
    bigViewport(tester);
    final container = containerWith(const VoiceState(
      loading: false,
      asrAvailable: false,
      ttsAvailable: false,
      backendReachable: true,
    ));
    await pump(tester, container);
    expect(find.textContaining('Micrófono no disponible'), findsOneWidget);
    container.dispose();
  });

  testWidgets('submitting a text command calls sendText', (tester) async {
    bigViewport(tester);
    final fake = _FakeVoiceNotifier();
    final container = containerWith(_idleState(), fake);
    await pump(tester, container);

    await tester.enterText(find.byType(TextField), 'pon música');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 300));

    expect(fake.lastText, 'pon música');
    expect(find.text('Respuesta de prueba'), findsOneWidget);
    container.dispose();
  });

  testWidgets('tapping the mic button triggers push-to-talk', (tester) async {
    bigViewport(tester);
    final fake = _FakeVoiceNotifier();
    final container = containerWith(_idleState(), fake);
    await pump(tester, container);

    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump(const Duration(milliseconds: 300));

    expect(fake.pushToTalkCalls, 1);
    container.dispose();
  });

  testWidgets('shows the unavailable view when the backend is unreachable', (tester) async {
    bigViewport(tester);
    final container = containerWith(const VoiceState(
      loading: false,
      backendReachable: false,
    ));
    await pump(tester, container);
    expect(find.text('Asistente no disponible'), findsOneWidget);
    expect(find.text('No se pudo contactar con el backend'), findsOneWidget);
    container.dispose();
  });

  testWidgets('parses VoiceTurn from JSON', (tester) async {
    final t = VoiceTurn.fromJson(const {
      'utterance': 'hola',
      'intent': 'help',
      'reply': '¿En qué te ayudo?',
      'acted': true,
      'at': 123,
    });
    expect(t.utterance, 'hola');
    expect(t.intent, 'help');
    expect(t.acted, true);
    expect(t.at, 123);
  });
}
