import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  UserModel? _user;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _user = ModalRoute.of(context)?.settings.arguments as UserModel?;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Sign-out confirm ──────────────────────────────────────────────────────
  void _confirmLogout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Text(
          'Are you sure you want to sign out of Fuelix?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.spaceGrotesk(
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              // Clear saved credentials on logout
              await _authService.logout();
              if (!mounted) return;
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (_) => false,
              );
            },
            child: Text(
              'Sign Out',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _formatDate(DateTime d) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _buildAddress(UserModel u) {
    final parts = [
      u.addressLine1,
      u.addressLine2,
      u.addressLine3,
    ].where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _user;

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
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Top bar ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _TopBar(isDark: isDark),
                    ),
                  ),
                  // ── Avatar hero card ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: _AvatarCard(user: user),
                    ),
                  ),
                  // ── Personal info ────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                      child: _ProfileSection(
                        title: 'PERSONAL INFORMATION',
                        isDark: isDark,
                        accentColor: AppColors.emerald,
                        children: [
                          _InfoTile(
                            icon: Icons.person_outline_rounded,
                            label: 'Full Name',
                            value: user?.fullName ?? '—',
                            isDark: isDark,
                            accent: AppColors.emerald,
                          ),
                          _InfoTile(
                            icon: Icons.badge_outlined,
                            label: 'NIC Number',
                            value: user?.nic ?? '—',
                            isDark: isDark,
                            accent: AppColors.emerald,
                          ),
                          _InfoTile(
                            icon: Icons.phone_outlined,
                            label: 'Mobile Number',
                            value: user?.mobile.isNotEmpty == true
                                ? user!.mobile
                                : '—',
                            isDark: isDark,
                            accent: AppColors.emerald,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── Address info ─────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: _ProfileSection(
                        title: 'ADDRESS',
                        isDark: isDark,
                        accentColor: AppColors.ocean,
                        children: [
                          _InfoTile(
                            icon: Icons.home_outlined,
                            label: 'Address',
                            value: user != null ? _buildAddress(user) : '—',
                            isDark: isDark,
                            accent: AppColors.ocean,
                            multiLine: true,
                          ),
                          _InfoTile(
                            icon: Icons.place_outlined,
                            label: 'District',
                            value: user?.district.isNotEmpty == true
                                ? user!.district
                                : '—',
                            isDark: isDark,
                            accent: AppColors.ocean,
                          ),
                          _InfoTile(
                            icon: Icons.map_outlined,
                            label: 'Province',
                            value: user?.province.isNotEmpty == true
                                ? user!.province
                                : '—',
                            isDark: isDark,
                            accent: AppColors.ocean,
                          ),
                          _InfoTile(
                            icon: Icons.markunread_mailbox_outlined,
                            label: 'Postal Code',
                            value: user?.postalCode.isNotEmpty == true
                                ? user!.postalCode
                                : '—',
                            isDark: isDark,
                            accent: AppColors.ocean,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── Account details ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: _ProfileSection(
                        title: 'ACCOUNT',
                        isDark: isDark,
                        accentColor: AppColors.amber,
                        children: [
                          _InfoTile(
                            icon: Icons.email_outlined,
                            label: 'Email Address',
                            value: user?.email ?? '—',
                            isDark: isDark,
                            accent: AppColors.amber,
                          ),
                          _InfoTile(
                            icon: Icons.calendar_today_outlined,
                            label: 'Member Since',
                            value: user?.createdAt != null
                                ? _formatDate(user!.createdAt!)
                                : '—',
                            isDark: isDark,
                            accent: AppColors.amber,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── Preferences ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: _ProfileSection(
                        title: 'PREFERENCES',
                        isDark: isDark,
                        accentColor: const Color(0xFF7C3AED),
                        children: [
                          _OptionTile(
                            icon: Icons.notifications_outlined,
                            label: 'Notifications',
                            isDark: isDark,
                            accent: const Color(0xFF7C3AED),
                            onTap: () {},
                          ),
                          _OptionTile(
                            icon: Icons.security_outlined,
                            label: 'Privacy & Security',
                            isDark: isDark,
                            accent: const Color(0xFF7C3AED),
                            onTap: () {},
                          ),
                          _OptionTile(
                            icon: Icons.help_outline_rounded,
                            label: 'Help & Support',
                            isDark: isDark,
                            accent: const Color(0xFF7C3AED),
                            onTap: () {},
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── Sign out ─────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
                      child: _SignOutButton(
                        onTap: _confirmLogout,
                        isDark: isDark,
                      ),
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
}

// ═════════════════════════════════════════════════════════════════════════════
// Top Bar
// ═════════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  final bool isDark;
  const _TopBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
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
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text('My Profile', style: Theme.of(context).textTheme.headlineMedium),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Avatar Hero Card
// ═════════════════════════════════════════════════════════════════════════════
class _AvatarCard extends StatelessWidget {
  final UserModel? user;
  const _AvatarCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final initials = user != null
        ? '${user!.firstName[0]}${user!.lastName[0]}'.toUpperCase()
        : 'U';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.emerald, AppColors.ocean],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withOpacity(0.30),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Avatar ───────────────────────────────────────────────────
          Stack(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.45),
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // Online dot
              Positioned(
                bottom: 3,
                right: 3,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4ADE80),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          // ── Info ─────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName ?? 'User',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user?.email ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.82),
                  ),
                ),
                const SizedBox(height: 10),
                // Tags row
                Row(
                  children: [
                    _HeroBadge(
                      icon: Icons.verified_rounded,
                      label: 'Verified',
                      color: Colors.white.withOpacity(0.22),
                    ),
                    const SizedBox(width: 8),
                    if (user?.province.isNotEmpty == true)
                      _HeroBadge(
                        icon: Icons.location_on_rounded,
                        label: user!.province,
                        color: Colors.white.withOpacity(0.15),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _HeroBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Section Container
// ═════════════════════════════════════════════════════════════════════════════
class _ProfileSection extends StatelessWidget {
  final String title;
  final bool isDark;
  final Color accentColor;
  final List<Widget> children;

  const _ProfileSection({
    required this.title,
    required this.isDark,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label with left accent line
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: accentColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accentColor,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Info Tile (read-only)
// ═════════════════════════════════════════════════════════════════════════════
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool isDark;
  final Color accent;
  final bool isLast;
  final bool multiLine;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.accent,
    this.isLast = false,
    this.multiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            crossAxisAlignment: multiLine
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: accent.withOpacity(isDark ? 0.12 : 0.07),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        height: multiLine ? 1.45 : 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 63,
            endIndent: 0,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Option Tile (tappable)
// ═════════════════════════════════════════════════════════════════════════════
class _OptionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color accent;
  final VoidCallback onTap;
  final bool isLast;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.accent,
    required this.onTap,
    this.isLast = false,
  });

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            decoration: BoxDecoration(
              borderRadius: widget.isLast
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    )
                  : BorderRadius.zero,
              color: _pressed
                  ? (widget.isDark
                        ? AppColors.darkSurfaceAlt
                        : AppColors.lightSurfaceAlt)
                  : Colors.transparent,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: widget.accent.withOpacity(
                      widget.isDark ? 0.12 : 0.07,
                    ),
                  ),
                  child: Icon(widget.icon, size: 16, color: widget.accent),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: widget.isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ],
            ),
          ),
        ),
        if (!widget.isLast)
          Divider(
            height: 1,
            indent: 63,
            color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sign Out Button
// ═════════════════════════════════════════════════════════════════════════════
class _SignOutButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isDark;
  const _SignOutButton({required this.onTap, required this.isDark});

  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _pressed
              ? AppColors.error.withOpacity(widget.isDark ? 0.20 : 0.12)
              : AppColors.error.withOpacity(widget.isDark ? 0.10 : 0.06),
          border: Border.all(
            color: AppColors.error.withOpacity(_pressed ? 0.55 : 0.28),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
            const SizedBox(width: 10),
            Text(
              'Sign Out',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
