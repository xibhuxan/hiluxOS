import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// One turn of the conversation (user utterance + assistant reply).
class VoiceTurn {
  final String utterance;
  final String intent;
  final String reply;
  final bool acted;
  final int at;

  const VoiceTurn({
    required this.utterance,
    required this.intent,
    required this.reply,
    required this.acted,
    required this.at,
  });

  factory VoiceTurn.fromJson(Map<String, dynamic> j) => VoiceTurn(
        utterance: j['utterance'] as String? ?? '',
        intent: j['intent'] as String? ?? 'unknown',
        reply: j['reply'] as String? ?? '',
        acted: j['acted'] as bool? ?? false,
        at: (j['at'] as num?)?.toInt() ?? 0,
      );
}

/// Immutable snapshot of the voice-assistant feature.
class VoiceState {
  /// 'idle' | 'listening' | 'thinking' | 'speaking'
  final String status;
  final bool asrAvailable;
  final bool ttsAvailable;
  final List<VoiceTurn> history;
  final bool loading;
  final bool backendReachable;

  const VoiceState({
    this.status = 'idle',
    this.asrAvailable = false,
    this.ttsAvailable = false,
    this.history = const [],
    this.loading = true,
    this.backendReachable = true,
  });

  bool get isBusy => status == 'listening' || status == 'thinking' || status == 'speaking';

  VoiceState copyWith({
    String? status,
    bool? asrAvailable,
    bool? ttsAvailable,
    List<VoiceTurn>? history,
    bool? loading,
    bool? backendReachable,
  }) =>
      VoiceState(
        status: status ?? this.status,
        asrAvailable: asrAvailable ?? this.asrAvailable,
        ttsAvailable: ttsAvailable ?? this.ttsAvailable,
        history: history ?? this.history,
        loading: loading ?? this.loading,
        backendReachable: backendReachable ?? this.backendReachable,
      );
}

class VoiceNotifier extends StateNotifier<VoiceState> {
  VoiceNotifier(this._api) : super(const VoiceState()) {
    refresh();
  }

  final ApiClient _api;
  final AudioPlayer _player = AudioPlayer();

  /// Load availability + history.
  Future<void> refresh() async {
    try {
      final res = await _api.get('/voice');
      final d = res.data as Map<String, dynamic>;
      final avail = d['availability'] as Map<String, dynamic>? ?? {};
      final history = (d['history'] as List<dynamic>? ?? [])
          .map((e) => VoiceTurn.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        status: d['status'] as String? ?? 'idle',
        asrAvailable: avail['asr'] as bool? ?? false,
        ttsAvailable: avail['tts'] as bool? ?? false,
        history: history,
        loading: false,
        backendReachable: true,
      );
    } catch (_) {
      state = state.copyWith(loading: false, backendReachable: false);
    }
  }

  /// Send a *text* command through the pipeline, then speak the reply.
  Future<void> sendText(String text) async {
    if (text.trim().isEmpty) return;
    state = state.copyWith(status: 'thinking');
    try {
      final res = await _api.post('/voice/command', data: {'text': text.trim()});
      final turn = VoiceTurn.fromJson(res.data as Map<String, dynamic>);
      _append(turn);
      state = state.copyWith(status: 'idle');
      await speakReply(turn.reply);
    } catch (_) {
      state = state.copyWith(status: 'idle', backendReachable: false);
    }
  }

  /// Push-to-talk: send captured PCM to /voice/listen, then speak the reply.
  /// On dev machines without a real mic pipeline the caller passes an empty
  /// buffer and the mock driver returns a canned command.
  Future<void> pushToTalk(Uint8List pcm) async {
    state = state.copyWith(status: 'listening');
    try {
      final res = await _api.post(
        '/voice/listen',
        data: pcm,
        // Raw octet-stream; Dio sends the bytes as-is.
        options: Options(contentType: 'application/octet-stream'),
      );
      final turn = VoiceTurn.fromJson(res.data as Map<String, dynamic>);
      _append(turn);
      state = state.copyWith(status: 'idle');
      await speakReply(turn.reply);
    } catch (_) {
      state = state.copyWith(status: 'idle', backendReachable: false);
    }
  }

  /// Synthesise `text` on the backend and play the returned WAV locally.
  Future<void> speakReply(String text) async {
    if (text.isEmpty) return;
    state = state.copyWith(status: 'speaking');
    try {
      final res = await _api.post(
        '/voice/speak',
        data: {'text': text},
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = res.data is Uint8List
          ? res.data as Uint8List
          : Uint8List.fromList(utf8.encode(res.data.toString()));
      await _player.play(BytesSource(bytes));
    } catch (_) {
      // TTS is best-effort; ignore playback errors.
    } finally {
      state = state.copyWith(status: 'idle');
    }
  }

  /// Clear the conversation history on the backend and locally.
  Future<void> clearHistory() async {
    try {
      await _api.delete('/voice/history');
    } catch (_) {}
    state = state.copyWith(history: const []);
  }

  void _append(VoiceTurn turn) {
    state = state.copyWith(history: [...state.history, turn]);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceState>(
  (ref) => VoiceNotifier(ref.watch(apiClientProvider)),
);
