import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../shared/models/station.dart';
import 'radio_provider.dart';
import 'widgets/spectrum_visualizer.dart';

class RadioScreen extends ConsumerStatefulWidget {
  const RadioScreen({super.key});
  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends ConsumerState<RadioScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(radioProvider.notifier).loadFavorites();
      ref.read(radioProvider.notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(radioProvider);
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Row(
              children: [
                const Text('Radio',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            isScrollable: false,
            tabs: const [Tab(text: 'Search'), Tab(text: 'Favorites'), Tab(text: 'History')],
          ),
          const SizedBox(height: 12),
          _nowPlaying(state),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _searchTab(state),
                _listTab(state.favorites, emptyText: 'No favorites yet'),
                _listTab(state.history, emptyText: 'No history yet'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nowPlaying(RadioState state) {
    if (state.current == null) return const SizedBox(height: 0);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(state.current!.name,
                style: const TextStyle(fontSize: 16, color: AppColors.onBackground)),
            if (state.current!.country != null)
              Text(state.current!.country!, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            SpectrumVisualizer(active: state.isPlaying),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.stop, color: AppColors.danger),
                  onPressed: () => ref.read(radioProvider.notifier).stop(),
                ),
                IconButton(
                  iconSize: 48,
                  icon: Icon(
                    state.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: AppColors.primary,
                  ),
                  onPressed: () {
                    final n = ref.read(radioProvider.notifier);
                    state.isPlaying ? n.pause() : n.resume();
                  },
                ),
                IconButton(
                  icon: Icon(
                    state.favorites.any((s) => s.url == state.current!.url)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: AppColors.danger,
                  ),
                  onPressed: () => ref.read(radioProvider.notifier).toggleFavorite(state.current!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchTab(RadioState state) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => ref.read(radioProvider.notifier).search(v),
            decoration: InputDecoration(
              hintText: 'Search stations…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => ref.read(radioProvider.notifier).search(_query.text),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (state.loading) const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.error != null)
            Expanded(child: Center(child: Text(state.error!)))
          else
            Expanded(child: _listTab(state.searchResults, emptyText: 'Type to search')),
        ],
      ),
    );
  }

  Widget _listTab(List<Station> stations, {required String emptyText}) {
    if (stations.isEmpty) {
      return Center(child: Text(emptyText, style: const TextStyle(color: AppColors.muted)));
    }
    return ListView.builder(
      itemCount: stations.length,
      itemBuilder: (context, i) {
        final s = stations[i];
        final isFav = ref.watch(radioProvider).favorites.any((f) => f.url == s.url);
        return ListTile(
          leading: s.favicon != null && s.favicon!.isNotEmpty
              ? Image.network(s.favicon!, width: 40, height: 40, errorBuilder: (_, __, ___) =>
                  const Icon(Icons.radio, color: AppColors.primary))
              : const Icon(Icons.radio, color: AppColors.primary),
          title: Text(s.name),
          subtitle: Text([if (s.country != null) s.country!, if (s.codec != null) s.codec!].join(' · '),
              style: const TextStyle(color: AppColors.muted)),
          trailing: IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: AppColors.danger),
            onPressed: () => ref.read(radioProvider.notifier).toggleFavorite(s),
          ),
          onTap: () => ref.read(radioProvider.notifier).play(s),
        );
      },
    );
  }
}