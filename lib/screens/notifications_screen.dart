import 'package:flutter/material.dart';
import 'package:fuelix_app/widgets/custom_button.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/tutorial_service.dart';
import '../widgets/tutorial_overlay.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? type;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.type,
  });

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

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

  // Tutorial keys
  final _keyNotificationList = GlobalKey();
  final _keyMenuButton = GlobalKey();
  bool _showTour = false;

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
    _checkNotificationsTour();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkNotificationsTour() async {
    final seen = await TutorialService.isSeen(TutorialKey.notificationsTour);
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _showTour = true);
    }
  }

  Future<void> _loadNotifications() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _notifications = [
        NotificationModel(
          id: '1',
          title: 'Fuel Log Added',
          message: 'You added 25.0L of Petrol 92 at CPC Colombo 3',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isRead: false,
          type: 'fuel_log',
        ),
        NotificationModel(
          id: '2',
          title: 'Wallet Top Up',
          message: 'LKR 2,000.00 added to your wallet via Credit Card',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          isRead: false,
          type: 'topup',
        ),
        NotificationModel(
          id: '3',
          title: 'Weekly Quota Reset',
          message:
              'Your weekly fuel quota has been reset. You have 25L available.',
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          isRead: true,
          type: 'quota',
        ),
        NotificationModel(
          id: '4',
          title: 'Low Wallet Balance',
          message:
              'Your wallet balance is below LKR 500. Top up to avoid interruption.',
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          isRead: true,
          type: 'system',
        ),
        NotificationModel(
          id: '5',
          title: 'Fuel Pass Generated',
          message:
              'Fuel Pass successfully generated for Toyota Corolla (WP-ABC-1234)',
          timestamp: DateTime.now().subtract(const Duration(days: 5)),
          isRead: true,
          type: 'system',
        ),
      ];
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(String id) async {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          title: _notifications[index].title,
          message: _notifications[index].message,
          timestamp: _notifications[index].timestamp,
          isRead: true,
          type: _notifications[index].type,
        );
      }
    });
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      _notifications = _notifications
          .map(
            (n) => NotificationModel(
              id: n.id,
              title: n.title,
              message: n.message,
              timestamp: n.timestamp,
              isRead: true,
              type: n.type,
            ),
          )
          .toList();
    });
    showAppSnackbar(
      context,
      message: 'All notifications marked as read',
      isSuccess: true,
    );
  }

  Future<void> _clearAll() async {
    setState(() {
      _notifications = [];
    });
    showAppSnackbar(
      context,
      message: 'All notifications cleared',
      isSuccess: true,
    );
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'fuel_log':
        return Icons.local_gas_station_rounded;
      case 'topup':
        return Icons.account_balance_wallet_rounded;
      case 'quota':
        return Icons.local_gas_station_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'fuel_log':
        return AppColors.emerald;
      case 'topup':
        return const Color(0xFF7C3AED);
      case 'quota':
        return AppColors.amber;
      default:
        return AppColors.ocean;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screen = Scaffold(
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
                      KeyedSubtree(
                        key: _keyMenuButton,
                        child: PopupMenuButton<String>(
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
                      : KeyedSubtree(
                          key: _keyNotificationList,
                          child: ListView.separated(
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
              ),
            ],
          ),
        ),
      ),
    );

    if (!_showTour) return screen;

    return SpotlightTour(
      steps: [
        TourStep(
          targetKey: _keyNotificationList,
          title: 'Your Notifications',
          body:
              'Here you\'ll see all alerts: fuel log confirmations, top-up receipts, quota updates, and system messages.',
          icon: Icons.notifications_active_rounded,
          gradient: [AppColors.ocean, AppColors.emerald],
          position: TooltipPosition.below,
        ),
        TourStep(
          targetKey: _keyMenuButton,
          title: 'Manage Notifications',
          body: 'Tap here to mark all as read or clear all notifications.',
          icon: Icons.more_vert_rounded,
          gradient: [AppColors.emerald, AppColors.ocean],
          position: TooltipPosition.below,
        ),
      ],
      onComplete: () async {
        await TutorialService.markSeen(TutorialKey.notificationsTour);
        if (mounted) setState(() => _showTour = false);
      },
      child: screen,
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

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'fuel_log':
        return AppColors.emerald;
      case 'topup':
        return const Color(0xFF7C3AED);
      case 'quota':
        return AppColors.amber;
      default:
        return AppColors.ocean;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'fuel_log':
        return Icons.local_gas_station_rounded;
      case 'topup':
        return Icons.account_balance_wallet_rounded;
      case 'quota':
        return Icons.local_gas_station_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}
