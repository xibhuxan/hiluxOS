import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/models/notification.dart';
import '../notification_provider.dart';

/// Animated overlay toast that shows incoming notifications.
/// Self-dismisses after 5 seconds (handled by the provider).
class NotificationToast extends ConsumerWidget {
  const NotificationToast({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(notificationProvider).toasts;

    if (toasts.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            // Show up to 3 stacked toasts
            ...toasts.take(3).map((n) => _ToastItem(notification: n)),
          ],
        ),
      ),
    );
  }
}

class _ToastItem extends ConsumerWidget {
  final AppNotification notification;
  const _ToastItem({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () {
          ref.read(notificationProvider.notifier).markRead(notification.id);
          // Navigate if action has a screen
          final screen = notification.action?['screen'] as String?;
          if (screen != null) {
            // Will be handled by the routing integration layer
          }
        },
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          offset: const Offset(0, 0),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: 1,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: _bgColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(_icon, color: _iconColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          notification.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (notification.message != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            notification.message!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        ref.read(notificationProvider.notifier).dismissToast(notification.id),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color get _bgColor {
    switch (notification.type) {
      case 'success':
        return AppColors.accent.withValues(alpha: 0.15);
      case 'warning':
        return AppColors.warning.withValues(alpha: 0.15);
      case 'error':
        return AppColors.danger.withValues(alpha: 0.15);
      default:
        return AppColors.primary.withValues(alpha: 0.15);
    }
  }

  Color get _borderColor {
    switch (notification.type) {
      case 'success':
        return AppColors.accent.withValues(alpha: 0.4);
      case 'warning':
        return AppColors.warning.withValues(alpha: 0.4);
      case 'error':
        return AppColors.danger.withValues(alpha: 0.4);
      default:
        return AppColors.primary.withValues(alpha: 0.4);
    }
  }

  Color get _iconColor {
    switch (notification.type) {
      case 'success':
        return AppColors.accent;
      case 'warning':
        return AppColors.warning;
      case 'error':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  IconData get _icon {
    switch (notification.type) {
      case 'success':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'error':
        return Icons.error;
      default:
        return Icons.info_outline;
    }
  }
}
