import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

class EventLogEntry {
  final String id;
  final String event;
  final Map<String, dynamic> payload;
  final String createdAt;

  EventLogEntry({
    required this.id,
    required this.event,
    required this.payload,
    required this.createdAt,
  });

  factory EventLogEntry.fromJson(Map<String, dynamic> j) => EventLogEntry(
        id: j['id'] as String,
        event: j['event'] as String,
        payload: (j['payload'] as Map<String, dynamic>?) ?? {},
        createdAt: j['createdAt'] as String,
      );
}

class EventLogState {
  final List<EventLogEntry> items;
  final String? nextCursor;
  final bool loading;
  final String? error;

  EventLogState({
    this.items = const [],
    this.nextCursor,
    this.loading = false,
    this.error,
  });

  EventLogState copyWith({
    List<EventLogEntry>? items,
    String? nextCursor,
    bool? loading,
    String? error,
  }) =>
      EventLogState(
        items: items ?? this.items,
        nextCursor: nextCursor ?? this.nextCursor,
        loading: loading ?? this.loading,
        error: error,
      );
}

class EventLogNotifier extends StateNotifier<EventLogState> {
  EventLogNotifier(this._api) : super(EventLogState());

  final ApiClient _api;

  Future<void> load({bool append = false}) async {
    if (state.loading) return;
    state = state.copyWith(loading: true, error: null);

    try {
      final cursor = append ? state.nextCursor : null;
      final params = <String, dynamic>{'limit': 50};
      if (cursor != null) params['cursor'] = cursor;

      final res = await _api.get('/event-log', query: params);
      final data = res.data as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((e) => EventLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      state = EventLogState(
        items: append ? [...state.items, ...items] : items,
        nextCursor: data['nextCursor'] as String?,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMore() => load(append: true);
}

final eventLogProvider = StateNotifierProvider<EventLogNotifier, EventLogState>(
  (ref) => EventLogNotifier(ref.watch(apiClientProvider)),
);
