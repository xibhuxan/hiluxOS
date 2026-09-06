// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/core/widgets/section_header.dart';
import '../lib/features/system_info/event_log_provider.dart';
import '../lib/features/system_info/system_provider.dart';
import '../lib/features/system_info/system_info_screen.dart';

class _FakeSystemNotifier extends SystemNotifier {
  _FakeSystemNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> load() async {}
  void setState(SystemState s) => state = s;
}

class _FakeEventLogNotifier extends EventLogNotifier {
  _FakeEventLogNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> load({bool append = false}) async {}
  void setState(EventLogState s) => state = s;
}

void main() {
  testWidgets('SystemInfoScreen renders SectionHeader for every card', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        systemProvider.overrideWith((ref) => _FakeSystemNotifier()
          ..setState(SystemState(
            info: SystemInfo(
              hostname: 'hiluxpi',
              platform: 'linux',
              arch: 'arm64',
              cpus: 4,
              totalMemoryMb: 4096,
              uptimeSeconds: 1000,
            ),
            resources: SystemResources(
              memoryUsagePercent: 42.5,
              freeMemoryMb: 2355,
              totalMemoryMb: 4096,
              cpuCount: 4,
              temperature: 45.0,
              load1m: 0.4,
              uptimeSeconds: 1000,
              diskFreeGb: 20.0,
              diskUsedPercent: 30,
            ),
          ))),
        eventLogProvider.overrideWith(
            (ref) => _FakeEventLogNotifier()..setState(EventLogState())),
      ],
      child: const MaterialApp(home: Scaffold(body: SystemInfoScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(SectionHeader), findsNWidgets(3));
    expect(find.text('Identity'), findsOneWidget);
    expect(find.text('Resources'), findsOneWidget);
    expect(find.text('Registro de eventos'), findsOneWidget);
  });

  testWidgets('error view retry button is in Spanish', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        systemProvider.overrideWith((ref) => _FakeSystemNotifier()
          ..setState(SystemState(error: 'boom'))),
        eventLogProvider.overrideWith(
            (ref) => _FakeEventLogNotifier()..setState(EventLogState())),
      ],
      child: const MaterialApp(home: Scaffold(body: SystemInfoScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
