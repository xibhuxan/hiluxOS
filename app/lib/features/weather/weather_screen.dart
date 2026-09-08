import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import 'weather_provider.dart';

/// Map a WMO weather-code icon name (from the backend) to a Material icon.
IconData weatherIcon(String name) {
  switch (name) {
    case 'wb_sunny':
      return Icons.wb_sunny;
    case 'cloud_queue':
      return Icons.cloud_queue;
    case 'cloud':
      return Icons.cloud;
    case 'blur_on':
      return Icons.blur_on;
    case 'grain':
      return Icons.grain;
    case 'ac_unit':
      return Icons.ac_unit;
    case 'flash_on':
      return Icons.flash_on;
    default:
      return Icons.help_outline;
  }
}

/// Compass label for a wind direction in degrees.
String windDirectionLabel(int degrees) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
  return dirs[((degrees % 360) / 45).round() % 8];
}

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weatherProvider);

    if (state.loading && state.current == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.current == null) {
      return _ErrorView(message: state.error!);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const _SearchBar(),
        const SizedBox(height: 12),
        if (state.current != null) _CurrentCard(current: state.current!),
        const SizedBox(height: 16),
        if (state.hourly.isNotEmpty) ...[
          const _SectionTitle('Próximas horas'),
          const SizedBox(height: 8),
          _HourlyRow(hourly: state.hourly),
          const SizedBox(height: 16),
        ],
        if (state.daily.isNotEmpty) ...[
          const _SectionTitle('Próximos días'),
          const SizedBox(height: 8),
          _DailyList(daily: state.daily),
        ],
      ],
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar();

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(color: AppColors.onBackground, fontSize: 14),
      textInputAction: TextInputAction.search,
      onSubmitted: (v) {
        ref.read(weatherProvider.notifier).searchCity(v);
        _controller.clear();
      },
      decoration: InputDecoration(
        hintText: 'Buscar ciudad…',
        hintStyle: const TextStyle(color: AppColors.muted),
        prefixIcon: const Icon(Icons.search, color: AppColors.muted, size: 20),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
    );
  }
}

class _CurrentCard extends StatelessWidget {
  const _CurrentCard({required this.current});
  final CurrentWeather current;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Text(current.locationName,
              style: const TextStyle(fontSize: 15, color: AppColors.muted)),
          const SizedBox(height: 8),
          Icon(weatherIcon(current.icon), size: 72, color: AppColors.primary),
          const SizedBox(height: 8),
          Text('${current.temperature.round()}°',
              style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w300,
                  color: AppColors.onBackground)),
          Text(current.description,
              style: const TextStyle(fontSize: 17, color: AppColors.onBackground)),
          const SizedBox(height: 4),
          Text('Sensación ${current.apparentTemperature.round()}°',
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DetailChip(
                icon: Icons.water_drop_outlined,
                label: 'Humedad',
                value: '${current.humidity}%',
              ),
              _DetailChip(
                icon: Icons.air,
                label: 'Viento',
                value: '${current.windSpeed.round()} km/h',
              ),
              _DetailChip(
                icon: Icons.explore_outlined,
                label: 'Dirección',
                value: windDirectionLabel(current.windDirection),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.onBackground)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onBackground));
  }
}

class _HourlyRow extends StatelessWidget {
  const _HourlyRow({required this.hourly});
  final List<HourlyEntry> hourly;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hourly.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final h = hourly[i];
          return Container(
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(h.hourLabel,
                    style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                Icon(weatherIcon(h.icon), size: 22, color: AppColors.primary),
                Text('${h.temperature.round()}°',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onBackground)),
                if (h.precipitationProbability > 0)
                  Text('${h.precipitationProbability}%',
                      style: const TextStyle(fontSize: 10, color: AppColors.primary)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DailyList extends StatelessWidget {
  const _DailyList({required this.daily});
  final List<DailyEntry> daily;

  static const _weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  String _dayLabel(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return isoDate;
    return _weekdays[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < daily.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.glassBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(_dayLabel(daily[i].date),
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.onBackground)),
                  ),
                  const SizedBox(width: 8),
                  Icon(weatherIcon(daily[i].icon),
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  if (daily[i].precipitationProbability > 0)
                    Text('${daily[i].precipitationProbability}%',
                        style:
                            const TextStyle(fontSize: 11, color: AppColors.primary)),
                  const Spacer(),
                  Text('${daily[i].tempMin.round()}°',
                      style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                  const SizedBox(width: 12),
                  Text('${daily[i].tempMax.round()}°',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onBackground)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 42, color: AppColors.muted.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          const Text('No se pudo cargar el clima',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          const SizedBox(height: 2),
          const Text('Comprueba la conexión a internet',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => ref.read(weatherProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

