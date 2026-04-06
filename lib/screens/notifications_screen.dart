import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../services/notification_local_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final NotificationLocalService _localService = NotificationLocalService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  UserModel? _user;
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
    _animCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is UserModel) {
      if (_user?.id != args.id) {
        _user = args;
        _loadNotifications();
      }
    } else {
      Future.delayed(Duration.zero, () {
        if (mounted && _user == null) {
          _errorMessage = 'User information not available';
          _isLoading = false;
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    if (_user?.id == null) {
      setState(() {
        _notifications = [];
        _isLoading = false;
        _errorMessage = 'Please login to view notifications';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.getUserNotifications(_user!.id!);

      if (result['success'] && mounted) {
        final List<dynamic> notificationsJson = result['data'] ?? [];

        final List<int> notificationIds = [];
        final List<Map<String, dynamic>> rawNotifications = [];

        for (var json in notificationsJson) {
          if (json is Map<String, dynamic>) {
            notificationIds.add(json['id'] as int);
            rawNotifications.add(json);
          }
        }

        final readStatusMap = await _localService.getReadStatus(
          notificationIds,
        );

        final List<NotificationModel> loadedNotifications = [];
        for (var json in rawNotifications) {
          final notificationId = json['id'] as int;
          final isRead = readStatusMap[notificationId] ?? false;
          loadedNotifications.add(
            NotificationModel.fromJson(json, isReadOverride: isRead),
          );
        }

        loadedNotifications.sort((a, b) {
          if (a.isRead != b.isRead) {
            return a.isRead ? 1 : -1;
          }
          return b.createdAt.compareTo(a.createdAt);
        });

        setState(() {
          _notifications = loadedNotifications;
          _isLoading = false;
        });
        print('✅ Loaded ${_notifications.length} notifications');
      } else {
        if (mounted) {
          setState(() {
            _notifications = [];
            _isLoading = false;
            _errorMessage = result['error'] ?? 'Failed to load notifications';
          });
        }
      }
    } catch (e) {
      print('❌ Exception loading notifications: $e');
      if (mounted) {
        setState(() {
          _notifications = [];
          _isLoading = false;
          _errorMessage = 'Network error. Please check your connection.';
        });
      }
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    if (_user?.id == null) return;

    try {
      await _localService.markAsRead(notificationId);

      setState(() {
        _notifications = _notifications.map((n) {
          if (n.id == notificationId) {
            return n.copyWith(isRead: true);
          }
          return n;
        }).toList();

        _notifications.sort((a, b) {
          if (a.isRead != b.isRead) {
            return a.isRead ? 1 : -1;
          }
          return b.createdAt.compareTo(a.createdAt);
        });
      });
    } catch (e) {
      print('Error marking as read locally: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    if (_user?.id == null) return;

    try {
      final allIds = _notifications.map((n) => n.id).toList();
      await _localService.markAllAsRead(allIds);

      setState(() {
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
    } catch (e) {
      print('Error marking all as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark all as read'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _clearAll() async {
    if (_user?.id == null) return;

    try {
      await _localService.clearAllReadStatus();
      await _loadNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared'),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
    } catch (e) {
      print('Error clearing notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clear notifications'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showNotificationDetail(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => NotificationDetailDialog(
        notification: notification,
        onMarkAsRead: () {
          if (!notification.isRead) {
            _markAsRead(notification.id);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = _notifications.where((n) => !n.isRead).length;

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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context, true),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          if (unreadCount > 0)
                            Text(
                              '$unreadCount unread',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.emerald,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_notifications.isNotEmpty && !_isLoading)
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
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: AppColors.emerald,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.emerald,
                              strokeWidth: 2,
                            ),
                          )
                        : _errorMessage != null
                        ? _buildErrorState(isDark)
                        : _notifications.isEmpty
                        ? _buildEmptyState(isDark)
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                            itemCount: _notifications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _buildNotificationCard(
                              _notifications[i],
                              isDark,
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
  }

  Widget _buildNotificationCard(NotificationModel notification, bool isDark) {
    final isPublic = notification.notificationType == 'PUBLIC';
    final color = _getTypeColor(notification);
    final icon = _getTypeIcon(notification);
    final isUnread = !notification.isRead;
    final hasBulkChanges =
        notification.data?['changes'] != null &&
        (notification.data!['changes'] as List).length > 1;

    return GestureDetector(
      onTap: () => _showNotificationDetail(notification),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isPublic
              ? LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                      : [const Color(0xFFF8FAFF), const Color(0xFFF0F4FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPublic
              ? null
              : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          border: Border.all(
            color: isUnread
                ? color.withOpacity(0.5)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isUnread ? 1.5 : 1,
          ),
          boxShadow: isUnread
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container with type-specific styling
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: isPublic
                    ? LinearGradient(
                        colors: [color, color.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isPublic ? null : color.withOpacity(isDark ? 0.15 : 0.1),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isPublic ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row with type badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: color,
                          ),
                          child: Text(
                            'NEW',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Message preview
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSub
                          : AppColors.lightTextSub,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Footer row with badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: isPublic
                              ? AppColors.ocean.withOpacity(0.15)
                              : AppColors.amber.withOpacity(0.15),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPublic
                                  ? Icons.public_rounded
                                  : Icons.lock_rounded,
                              size: 10,
                              color: isPublic
                                  ? AppColors.ocean
                                  : AppColors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPublic ? 'PUBLIC' : 'PRIVATE',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isPublic
                                    ? AppColors.ocean
                                    : AppColors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bulk changes badge
                      if (hasBulkChanges)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: AppColors.emerald.withOpacity(0.15),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.compare_arrows_rounded,
                                size: 10,
                                color: AppColors.emerald,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(notification.data!['changes'] as List).length} UPDATES',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.emerald,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Updated by (only for public)
                      if (isPublic && notification.data?['updatedBy'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: AppColors.amber.withOpacity(0.15),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 10,
                                color: AppColors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'By: ${notification.data!['updatedBy']}',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Timestamp
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
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error.withOpacity(isDark ? 0.15 : 0.1),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Failed to load notifications',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadNotifications,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
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

  Color _getTypeColor(NotificationModel notification) {
    if (notification.data != null && notification.data!.containsKey('type')) {
      final dataType = notification.data!['type'] as String;
      if (dataType == 'FUEL_LOG') return AppColors.emerald;
      if (dataType == 'QUOTA_UPDATE') return AppColors.ocean;
      if (dataType == 'PRICE_UPDATE') return const Color(0xFFF97316);
    }
    return notification.notificationType == 'PRIVATE'
        ? AppColors.amber
        : AppColors.ocean;
  }

  IconData _getTypeIcon(NotificationModel notification) {
    if (notification.data != null && notification.data!.containsKey('type')) {
      final dataType = notification.data!['type'] as String;
      if (dataType == 'FUEL_LOG') return Icons.local_gas_station_rounded;
      if (dataType == 'QUOTA_UPDATE') return Icons.update_rounded;
      if (dataType == 'PRICE_UPDATE') return Icons.attach_money_rounded;
    }
    return notification.notificationType == 'PRIVATE'
        ? Icons.person_outline_rounded
        : Icons.public_rounded;
  }
}

// ==================== DETAIL DIALOG ====================

class NotificationDetailDialog extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onMarkAsRead;

  const NotificationDetailDialog({
    super.key,
    required this.notification,
    required this.onMarkAsRead,
  });

  @override
  State<NotificationDetailDialog> createState() =>
      _NotificationDetailDialogState();
}

class _NotificationDetailDialogState extends State<NotificationDetailDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _isMarkedRead = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();

    if (!widget.notification.isRead && !_isMarkedRead) {
      _isMarkedRead = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onMarkAsRead();
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPublic = widget.notification.notificationType == 'PUBLIC';
    final color = _getTypeColor(widget.notification);
    final icon = _getTypeIcon(widget.notification);
    final hasBulkChanges =
        widget.notification.data?['changes'] != null &&
        (widget.notification.data!['changes'] as List).length > 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient background
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  gradient: isPublic
                      ? LinearGradient(
                          colors: [color, color.withOpacity(0.85)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [
                            color.withOpacity(0.85),
                            color.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: Icon(icon, size: 28, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.notification.title,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.notification.formattedDate,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: color.withOpacity(0.15),
                            border: Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPublic
                                    ? Icons.public_rounded
                                    : Icons.lock_rounded,
                                size: 14,
                                color: color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isPublic
                                    ? 'PUBLIC NOTIFICATION'
                                    : 'PRIVATE NOTIFICATION',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Bulk changes badge
                        if (hasBulkChanges)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: AppColors.emerald.withOpacity(0.15),
                              border: Border.all(
                                color: AppColors.emerald.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.compare_arrows_rounded,
                                  size: 14,
                                  color: AppColors.emerald,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${(widget.notification.data!['changes'] as List).length} ITEMS UPDATED',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.emerald,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Updated by (only for public)
                        if (isPublic &&
                            widget.notification.data?['updatedBy'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: AppColors.amber.withOpacity(0.15),
                              border: Border.all(
                                color: AppColors.amber.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.admin_panel_settings_rounded,
                                  size: 14,
                                  color: AppColors.amber,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'UPDATED BY: ${widget.notification.data!['updatedBy']}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Message
                    Text(
                      widget.notification.message,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        height: 1.5,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Divider
                    Container(
                      height: 1,
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                    const SizedBox(height: 16),

                    // Additional info based on notification type
                    if (widget.notification.data != null)
                      _buildAdditionalInfo(isDark, widget.notification.data!),

                    // Timestamp
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatFullDate(widget.notification.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
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

  Widget _buildAdditionalInfo(bool isDark, Map<String, dynamic> data) {
    final type = data['type'] as String;

    if (type == 'FUEL_LOG') {
      final litres = data['litres']?.toString() ?? '0';
      final fuelGrade = data['fuelGrade'] ?? 'Unknown';
      final vehicleName = data['vehicleName'] ?? 'Unknown';
      final totalCost = data['totalCost']?.toString() ?? '0';

      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.emerald.withOpacity(isDark ? 0.1 : 0.05),
          border: Border.all(color: AppColors.emerald.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⛽ Fuel Details',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.emerald,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow('Vehicle:', vehicleName, isDark),
            _infoRow('Fuel Grade:', fuelGrade, isDark),
            _infoRow('Litres:', '$litres L', isDark),
            _infoRow(
              'Total Cost:',
              'LKR ${double.parse(totalCost).toStringAsFixed(2)}',
              isDark,
            ),
          ],
        ),
      );
    } else if (type == 'QUOTA_UPDATE') {
      final changes = data['changes'] as List?;
      final changeCount = changes?.length ?? 1;
      final effectiveDate = data['effectiveDate'] ?? 'Next Monday';
      final updatedBy = data['updatedBy'] ?? 'Administrator';
      final isBulk = changeCount > 1;

      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.ocean.withOpacity(isDark ? 0.1 : 0.05),
          border: Border.all(color: AppColors.ocean.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isBulk ? Icons.compare_arrows_rounded : Icons.update_rounded,
                  size: 18,
                  color: AppColors.ocean,
                ),
                const SizedBox(width: 8),
                Text(
                  isBulk ? '📊 Bulk Quota Update' : '📊 Quota Update Details',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ocean,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (isBulk && changes != null)
              ...changes
                  .map(
                    (change) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _infoRow(
                        change['vehicleType'] ?? 'Unknown',
                        '${(change['oldQuota'] as num?)?.toDouble() ?? 0}L → ${(change['newQuota'] as num?)?.toDouble() ?? 0}L',
                        isDark,
                        isBulk: true,
                      ),
                    ),
                  )
                  .toList()
            else
              Column(
                children: [
                  _infoRow(
                    'Vehicle Type:',
                    data['vehicleType'] ?? 'Unknown',
                    isDark,
                  ),
                  _infoRow(
                    'Old Quota:',
                    '${(data['oldQuota'] as num?)?.toDouble() ?? 0} L',
                    isDark,
                  ),
                  _infoRow(
                    'New Quota:',
                    '${(data['newQuota'] as num?)?.toDouble() ?? 0} L',
                    isDark,
                  ),
                ],
              ),

            const SizedBox(height: 8),
            _infoRow('Effective Date:', effectiveDate, isDark),
            _infoRow('Updated By:', updatedBy, isDark),

            if (isBulk)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.emerald.withOpacity(0.1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 12,
                      color: AppColors.emerald,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$changeCount vehicle types updated in this notification',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.emerald,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    } else if (type == 'PRICE_UPDATE') {
      final changes = data['changes'] as List?;
      final changeCount = changes?.length ?? 1;
      final updatedBy = data['updatedBy'] ?? 'Administrator';
      final isBulk = changeCount > 1;

      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFF97316).withOpacity(isDark ? 0.1 : 0.05),
          border: Border.all(color: const Color(0xFFF97316).withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.attach_money_rounded,
                  size: 18,
                  color: const Color(0xFFF97316),
                ),
                const SizedBox(width: 8),
                Text(
                  isBulk ? '💰 Bulk Price Update' : '💰 Price Update Details',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF97316),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (isBulk && changes != null)
              ...changes
                  .map(
                    (change) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _infoRow(
                        change['fuelGrade'] ?? 'Unknown',
                        'LKR ${(change['oldPrice'] as num?)?.toDouble() ?? 0} → LKR ${(change['newPrice'] as num?)?.toDouble() ?? 0}',
                        isDark,
                        isBulk: true,
                      ),
                    ),
                  )
                  .toList()
            else
              Column(
                children: [
                  _infoRow(
                    'Fuel Grade:',
                    data['fuelGrade'] ?? 'Unknown',
                    isDark,
                  ),
                  _infoRow(
                    'Old Price:',
                    'LKR ${(data['oldPrice'] as num?)?.toDouble() ?? 0}',
                    isDark,
                  ),
                  _infoRow(
                    'New Price:',
                    'LKR ${(data['newPrice'] as num?)?.toDouble() ?? 0}',
                    isDark,
                  ),
                ],
              ),

            const SizedBox(height: 8),
            _infoRow('Updated By:', updatedBy, isDark),

            if (isBulk)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.emerald.withOpacity(0.1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 12,
                      color: AppColors.emerald,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$changeCount fuel grades updated in this notification',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.emerald,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _infoRow(
    String label,
    String value,
    bool isDark, {
    bool isBulk = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isBulk ? 100 : 90,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour < 12 ? 'AM' : 'PM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:$minute $ampm';
  }

  Color _getTypeColor(NotificationModel notification) {
    if (notification.data != null && notification.data!.containsKey('type')) {
      final dataType = notification.data!['type'] as String;
      if (dataType == 'FUEL_LOG') return AppColors.emerald;
      if (dataType == 'QUOTA_UPDATE') return AppColors.ocean;
      if (dataType == 'PRICE_UPDATE') return const Color(0xFFF97316);
    }
    return notification.notificationType == 'PRIVATE'
        ? AppColors.amber
        : AppColors.ocean;
  }

  IconData _getTypeIcon(NotificationModel notification) {
    if (notification.data != null && notification.data!.containsKey('type')) {
      final dataType = notification.data!['type'] as String;
      if (dataType == 'FUEL_LOG') return Icons.local_gas_station_rounded;
      if (dataType == 'QUOTA_UPDATE') return Icons.update_rounded;
      if (dataType == 'PRICE_UPDATE') return Icons.attach_money_rounded;
    }
    return notification.notificationType == 'PRIVATE'
        ? Icons.person_outline_rounded
        : Icons.public_rounded;
  }
}
