import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../widgets/custom_button.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadNotifications();
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final notifications = await NotificationService.getNotifications();
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(String id) async {
    await NotificationService.markAsRead(id);
    await _loadNotifications();
  }

  Future<void> _markAllAsRead() async {
    await NotificationService.markAllAsRead();
    await _loadNotifications();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        backgroundColor: AppColors.emerald,
      ),
    );
  }

  Future<void> _clearAll() async {
    await NotificationService.clearAll();
    await _loadNotifications();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications cleared'),
        backgroundColor: AppColors.emerald,
      ),
    );
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.fuelLog:
        return Icons.local_gas_station_rounded;
      case NotificationType.topup:
        return Icons.account_balance_wallet_rounded;
      case NotificationType.quota:
        return Icons.local_gas_station_rounded;
      case NotificationType.quotaUpdate:
        return Icons.update_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.fuelLog:
        return AppColors.emerald;
      case NotificationType.topup:
        return const Color(0xFF7C3AED);
      case NotificationType.quota:
        return AppColors.amber;
      case NotificationType.quotaUpdate:
        return AppColors.ocean;
      default:
        return AppColors.ocean;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0D1117), const Color(0xFF0A1628)]
                : [const Color(0xFFF0FDF8), const Color(0xFFEFF6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isDark
                              ? AppColors.darkSurfaceAlt
                              : AppColors.lightSurfaceAlt,
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: isDark
                              ? AppColors.darkTextSub
                              : AppColors.lightTextSub,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    if (_notifications.isNotEmpty)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'mark_all') {
                            _markAllAsRead();
                          } else if (value == 'clear_all') {
                            _clearAll();
                          }
                        },
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: isDark
                              ? AppColors.darkTextSub
                              : AppColors.lightTextSub,
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'mark_all',
                            child: Row(
                              children: [
                                Icon(Icons.done_all_rounded, size: 18),
                                SizedBox(width: 10),
                                Text('Mark all as read'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'clear_all',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18),
                                SizedBox(width: 10),
                                Text('Clear all'),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.emerald,
                            strokeWidth: 2,
                          ),
                        )
                      : _notifications.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _NotificationCard(
                            notification: _notifications[i],
                            isDark: isDark,
                            onTap: () => _markAsRead(_notifications[i].id),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.emerald.withOpacity(0.15),
                  AppColors.ocean.withOpacity(0.15),
                ],
              ),
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 38,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When you receive notifications, they\'ll appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final bool isDark;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getTypeColor(notification.type);
    final icon = _getTypeIcon(notification.type);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border.all(
            color: notification.isRead
                ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                : color.withOpacity(0.5),
            width: notification.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: color.withOpacity(isDark ? 0.15 : 0.08),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSub
                          : AppColors.lightTextSub,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.formattedDate,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.fuelLog:
        return AppColors.emerald;
      case NotificationType.topup:
        return const Color(0xFF7C3AED);
      case NotificationType.quota:
        return AppColors.amber;
      case NotificationType.quotaUpdate:
        return AppColors.ocean;
      default:
        return AppColors.ocean;
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.fuelLog:
        return Icons.local_gas_station_rounded;
      case NotificationType.topup:
        return Icons.account_balance_wallet_rounded;
      case NotificationType.quota:
        return Icons.local_gas_station_rounded;
      case NotificationType.quotaUpdate:
        return Icons.update_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}
