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

      // Return true to indicate refresh needed when going back
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

  IconData _getTypeIcon(String type, Map<String, dynamic>? data) {
    if (data != null && data.containsKey('type')) {
      final dataType = data['type'] as String;
      if (dataType == 'FUEL_LOG') return Icons.local_gas_station_rounded;
      if (dataType == 'QUOTA_UPDATE') return Icons.update_rounded;
    }
    return type == 'PRIVATE'
        ? Icons.person_outline_rounded
        : Icons.public_rounded;
  }

  Color _getTypeColor(String type, Map<String, dynamic>? data) {
    if (data != null && data.containsKey('type')) {
      final dataType = data['type'] as String;
      if (dataType == 'FUEL_LOG') return AppColors.emerald;
      if (dataType == 'QUOTA_UPDATE') return AppColors.ocean;
    }
    return type == 'PRIVATE' ? AppColors.amber : AppColors.ocean;
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
                      onTap: () => Navigator.pop(
                        context,
                        true,
                      ), // Return true to trigger refresh
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
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _NotificationCard(
                              notification: _notifications[i],
                              isDark: isDark,
                              onTap: () =>
                                  _showNotificationDetail(_notifications[i]),
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
    final color = _getTypeColor(
      notification.notificationType,
      notification.data,
    );
    final icon = _getTypeIcon(notification.notificationType, notification.data);
    final isUnread = !notification.isRead;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border.all(
            color: isUnread
                ? color.withOpacity(0.6)
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
                      if (isUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: color,
                          ),
                          child: Text(
                            'NEW',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSub
                          : AppColors.lightTextSub,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: notification.notificationType == 'PRIVATE'
                              ? AppColors.amber.withOpacity(0.15)
                              : AppColors.ocean.withOpacity(0.15),
                        ),
                        child: Text(
                          notification.notificationType == 'PRIVATE'
                              ? 'Private'
                              : 'Public',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: notification.notificationType == 'PRIVATE'
                                ? AppColors.amber
                                : AppColors.ocean,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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

  Color _getTypeColor(String type, Map<String, dynamic>? data) {
    if (data != null && data.containsKey('type')) {
      final dataType = data['type'] as String;
      if (dataType == 'FUEL_LOG') return AppColors.emerald;
      if (dataType == 'QUOTA_UPDATE') return AppColors.ocean;
    }
    return type == 'PRIVATE' ? AppColors.amber : AppColors.ocean;
  }

  IconData _getTypeIcon(String type, Map<String, dynamic>? data) {
    if (data != null && data.containsKey('type')) {
      final dataType = data['type'] as String;
      if (dataType == 'FUEL_LOG') return Icons.local_gas_station_rounded;
      if (dataType == 'QUOTA_UPDATE') return Icons.update_rounded;
    }
    return type == 'PRIVATE'
        ? Icons.person_outline_rounded
        : Icons.public_rounded;
  }
}

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

  Color _getTypeColor(String type, Map<String, dynamic>? data) {
    if (data != null && data.containsKey('type')) {
      final dataType = data['type'] as String;
      if (dataType == 'FUEL_LOG') return AppColors.emerald;
      if (dataType == 'QUOTA_UPDATE') return AppColors.ocean;
    }
    return type == 'PRIVATE' ? AppColors.amber : AppColors.ocean;
  }

  IconData _getTypeIcon(String type, Map<String, dynamic>? data) {
    if (data != null && data.containsKey('type')) {
      final dataType = data['type'] as String;
      if (dataType == 'FUEL_LOG') return Icons.local_gas_station_rounded;
      if (dataType == 'QUOTA_UPDATE') return Icons.update_rounded;
    }
    return type == 'PRIVATE'
        ? Icons.person_outline_rounded
        : Icons.public_rounded;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _getTypeColor(
      widget.notification.notificationType,
      widget.notification.data,
    );
    final icon = _getTypeIcon(
      widget.notification.notificationType,
      widget.notification.data,
    );
    final isUnread = !widget.notification.isRead;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
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
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
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
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
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

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type badge and read status
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: color.withOpacity(0.15),
                            border: Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 14, color: color),
                              const SizedBox(width: 6),
                              Text(
                                widget.notification.notificationType ==
                                        'PRIVATE'
                                    ? 'PRIVATE NOTIFICATION'
                                    : 'PUBLIC NOTIFICATION',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (isUnread)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: AppColors.emerald.withOpacity(0.15),
                              border: Border.all(
                                color: AppColors.emerald.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              'UNREAD',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.emerald,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

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
                    const SizedBox(height: 20),

                    // Divider
                    Container(
                      height: 1,
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                    const SizedBox(height: 16),

                    // Additional info based on notification type
                    if (widget.notification.data != null &&
                        widget.notification.data!.containsKey('type'))
                      _buildAdditionalInfo(isDark, widget.notification.data!),

                    // Full timestamp
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

                    // Single Close button only
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.emerald.withOpacity(isDark ? 0.1 : 0.05),
          border: Border.all(color: AppColors.emerald.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fuel Details',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.emerald,
              ),
            ),
            const SizedBox(height: 8),
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
      final vehicleType = data['vehicleType'] ?? 'Unknown';
      final oldQuota = data['oldQuota']?.toString() ?? '0';
      final newQuota = data['newQuota']?.toString() ?? '0';
      final updatedBy = data['updatedBy'] ?? 'Admin';
      final effectiveDate = data['effectiveDate'] ?? 'Next Monday';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.ocean.withOpacity(isDark ? 0.1 : 0.05),
          border: Border.all(color: AppColors.ocean.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quota Update Details',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.ocean,
              ),
            ),
            const SizedBox(height: 8),
            _infoRow('Vehicle Type:', vehicleType, isDark),
            _infoRow('Old Quota:', '$oldQuota L', isDark),
            _infoRow('New Quota:', '$newQuota L', isDark),
            _infoRow('Updated By:', updatedBy, isDark),
            _infoRow('Effective Date:', effectiveDate, isDark),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
