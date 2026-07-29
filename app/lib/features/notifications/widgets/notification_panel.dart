import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../notification_provider.dart';

/// Overlay panel that shows the notification history.
/// Opens from the top of the screen, triggered by the bell icon.
class NotificationPanel extends ConsumerStatefulWidget {
  const NotificationPanel({super.key});

  @override
  ConsumerState<NotificationPanel> createState() => NotificationPanelState();
}

class NotificationPanelState extends ConsumerState<NotificationPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  bool _open = false;

  bool get isOpen => _open;
  bool get isAnimating => _controller.isAnimating;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
  }

  void open() {
    if (!_open) {
      setState(() => _open = true);
      _controller.forward();
    }
  }

  void close() {
    if (_open) {
      _controller.reverse().then((_) => setState(() => _open = false));
    }
  }

  void toggle() {
    if (_open) {
      close();
    } else {
      open();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When fully closed and not animating, don't render at all.
    if (!_open && !_controller.isAnimating) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(
                bottom: BorderSide(color: AppColors.glassBorder),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const Divider(color: AppColors.glassBorder, height: 1),
                  _buildList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          const Text(
            'Notificaciones',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () =>
                ref.read(notificationProvider.notifier).markAllRead(),
            child: const Text(
              'Limpiar todo',
              style: TextStyle(color: AppColors.primary, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
            onPressed: close,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final items = ref.watch(notificationProvider).items;
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'Sin notificaciones',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ),
      );
    }
    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final n = items[index];
          return _NotificationItem(notification: n);
        },
      ),
    );
  }
}

class _NotificationItem extends ConsumerWidget {
  final dynamic notification;

  const _NotificationItem({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;

    return Material(
      color: AppColors.surfaceVariant.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () {
          ref.read(notificationProvider.notifier).markRead(n.id);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon(n.type), color: _iconColor(n.type), size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (n.message != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        n.message,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo(n.createdAt),
                      style: const TextStyle(color: AppColors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'success': return Icons.check_circle;
      case 'warning': return Icons.warning_amber_rounded;
      case 'error': return Icons.error;
      default: return Icons.info_outline;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'success': return AppColors.accent;
      case 'warning': return AppColors.warning;
      case 'error': return AppColors.danger;
      default: return AppColors.primary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}