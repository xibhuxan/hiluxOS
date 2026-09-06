import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../vehicle_provider.dart';
import 'control_tiles.dart';
import 'control_widgets.dart';
import 'window_door_rows.dart';

/// The actuation face: engine button + one glass card per actuation group.
class ControlPanel extends ConsumerWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(vehicleProvider).snapshot;
    if (snap == null) return const SizedBox.shrink();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          sliver: SliverToBoxAdapter(child: StaggeredEntrance(index: 0, child: EngineButton())),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 12),
          sliver: SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 1,
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(icon: Icons.lightbulb, title: 'Luces'),
                    ControlToggle(
                      icon: Icons.wb_twighlight,
                      label: 'Posición',
                      value: snap.positionLights,
                      onChanged: (v) => ref.read(vehicleProvider.notifier).setLights(position: v),
                    ),
                    ControlToggle(
                      icon: Icons.lightbulb_outline,
                      label: 'Cortas',
                      value: snap.lowBeams,
                      onChanged: (v) => ref.read(vehicleProvider.notifier).setLights(low: v),
                    ),
                    ControlToggle(
                      icon: Icons.highlight,
                      label: 'Largas',
                      helper: 'Requiere cortas encendidas',
                      value: snap.highBeams,
                      onChanged: (v) => ref.read(vehicleProvider.notifier).setLights(
                            high: v,
                            low: v ? true : null,
                          ),
                    ),
                    ControlToggle(
                      icon: Icons.water_drop,
                      label: 'Antiniebla',
                      value: snap.fogLights,
                      onChanged: (v) => ref.read(vehicleProvider.notifier).setLights(fog: v),
                    ),
                    ControlToggle(
                      icon: Icons.add_road,
                      label: 'Auxiliares',
                      value: snap.auxiliaryLights,
                      onChanged: (v) => ref.read(vehicleProvider.notifier).setLights(auxiliary: v),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 12),
          sliver: SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 2,
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(icon: Icons.swap_horiz, title: 'Intermitentes'),
                    const SizedBox(height: 6),
                    TurnSignalButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 12),
          sliver: SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 3,
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(icon: Icons.lock, title: 'Cierre y alarma'),
                    const SizedBox(height: 6),
                    const LockAlarmRow(),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 12),
          sliver: SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 4,
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(icon: Icons.window, title: 'Ventanillas'),
                    for (final w in snap.windows) WindowRow(window: w),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 12),
          sliver: SliverToBoxAdapter(
            child: StaggeredEntrance(
              index: 5,
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(icon: Icons.meeting_room, title: 'Puertas'),
                    for (final d in snap.doors) DoorRow(door: d),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}