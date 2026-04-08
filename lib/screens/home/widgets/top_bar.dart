import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/user_model.dart';

class TopBar extends StatefulWidget {
  final UserModel? user;
  final int unreadCount;
  final bool isDark;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onQrScanTap;
  final Key? notificationsKey;
  final Key? qrScanKey;

  const TopBar({
    super.key,
    required this.user,
    required this.unreadCount,
    required this.isDark,
    required this.onProfileTap,
    required this.onNotificationsTap,
    required this.onQrScanTap,
    this.notificationsKey,
    this.qrScanKey,
  });

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> with TickerProviderStateMixin {
  AnimationController? _bellController;
  Animation<double>? _bellRotation;
  late AnimationController _dotController;
  late Animation<double> _dotScale;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _dotScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _dotController, curve: Curves.elasticOut),
    );

    if (widget.unreadCount > 0) {
      _initBellAnimation();
      _dotController.forward(from: 0);
    }

    // Debug print to check role
    print('TopBar - User role: ${widget.user?.role}');
    print('TopBar - isStaff: ${widget.user?.isStaff}');
  }

  void _initBellAnimation() {
    if (_bellController != null) return;
    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: false);
    _bellRotation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.12), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 0.12, end: -0.12), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.08), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.04), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 0.04, end: -0.04), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _bellController!, curve: Curves.easeInOut),
        );
  }

  @override
  void didUpdateWidget(TopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unreadCount == 0 && widget.unreadCount > 0) {
      _initBellAnimation();
      _dotController.forward(from: 0);
    } else if (oldWidget.unreadCount > 0 && widget.unreadCount == 0) {
      _bellController?.dispose();
      _bellController = null;
      _bellRotation = null;
    }
  }

  @override
  void dispose() {
    _bellController?.dispose();
    _dotController.dispose();
    super.dispose();
  }

  /// Check if user is staff or admin (should see QR scanner)
  bool get _showQrScanner {
    final role = widget.user?.role?.toUpperCase() ?? '';
    final shouldShow = role == 'STAFF' || role == 'ADMIN';
    print('TopBar - _showQrScanner: $shouldShow (role: $role)');
    return shouldShow;
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = widget.unreadCount > 0;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [AppColors.emerald, AppColors.ocean],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.local_gas_station_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.emerald, AppColors.ocean],
          ).createShader(bounds),
          child: Text(
            'FUELIX',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 2.5,
            ),
          ),
        ),
        const Spacer(),
        // QR Scanner Button - Only visible for STAFF or ADMIN
        if (_showQrScanner) ...[
          KeyedSubtree(
            key: widget.qrScanKey,
            child: GestureDetector(
              onTap: widget.onQrScanTap,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: widget.isDark
                      ? AppColors.darkSurfaceAlt
                      : AppColors.lightSurfaceAlt,
                  border: Border.all(
                    color: widget.isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 20,
                  color: widget.isDark
                      ? AppColors.darkTextSub
                      : AppColors.lightTextSub,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        KeyedSubtree(
          key: widget.notificationsKey,
          child: GestureDetector(
            onTap: widget.onNotificationsTap,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                if (_bellController != null) _bellController!,
                _dotController,
              ]),
              builder: (context, child) {
                return Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: widget.isDark
                        ? AppColors.darkSurfaceAlt
                        : AppColors.lightSurfaceAlt,
                    border: Border.all(
                      color: widget.isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (hasUnread && _bellController != null)
                          Transform.rotate(
                            angle: _bellRotation?.value ?? 0,
                            child: Icon(
                              Icons.notifications,
                              size: 20,
                              color: AppColors.amber,
                            ),
                          )
                        else if (hasUnread)
                          Icon(
                            Icons.notifications,
                            size: 20,
                            color: AppColors.amber,
                          )
                        else
                          Icon(
                            Icons.notifications_outlined,
                            size: 18,
                            color: widget.isDark
                                ? AppColors.darkTextSub
                                : AppColors.lightTextSub,
                          ),
                        // Red dot indicator (replaces count)
                        if (hasUnread)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: ScaleTransition(
                              scale: _dotScale,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: widget.onProfileTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [AppColors.amber, AppColors.emerald],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                widget.user != null
                    ? widget.user!.firstName[0].toUpperCase()
                    : 'U',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
