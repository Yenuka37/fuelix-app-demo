import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/topup_model.dart';
import '../models/fuel_log_model.dart';
import '../database/db_helper.dart';
import '../services/tutorial_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/tutorial_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  UserModel? _user;
  List<VehicleModel> _vehicles = [];
  WalletModel? _wallet;
  List<FuelLogModel> _recentLogs = [];
  Map<String, double> _stats = {
    'total_logs': 0,
    'total_litres': 0,
    'total_km': 0,
  };
  final _db = DbHelper();

  // ── Tutorial keys ─────────────────────────────────────────────────────────
  final _keyWelcome = GlobalKey();
  final _keyVehicles = GlobalKey();
  final _keyWallet = GlobalKey();
  final _keyActions = GlobalKey();
  bool _showTour = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final u = ModalRoute.of(context)?.settings.arguments as UserModel?;
    if (u != null && _user?.id != u.id) {
      _user = u;
      _loadAll();
      _checkHomeTour();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadVehicles(), _loadWallet(), _loadFuelData()]);
  }

  Future<void> _checkHomeTour() async {
    final seen = await TutorialService.isSeen(TutorialKey.homeTour);
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _showTour = true);
    }
  }

  Future<void> _loadVehicles() async {
    if (_user?.id == null) return;
    final list = await _db.getVehiclesByUser(_user!.id!);
    if (mounted) setState(() => _vehicles = list);
  }

  Future<void> _loadWallet() async {
    if (_user?.id == null) return;
    final w = await _db.getWallet(_user!.id!);
    if (mounted) setState(() => _wallet = w);
  }

  Future<void> _loadFuelData() async {
    if (_user?.id == null) return;
    final logs = await _db.getFuelLogsByUser(_user!.id!, limit: 10);
    final stats = await _db.getFuelLogStats(_user!.id!);
    if (mounted) {
      setState(() {
        _recentLogs = logs;
        _stats = stats;
      });
    }
  }

  void _goToVehicles() async {
    await Navigator.pushNamed(context, '/vehicles', arguments: _user);
    _loadVehicles();
  }

  void _goToTopUp() async {
    await Navigator.pushNamed(context, '/topup', arguments: _user);
    _loadWallet();
  }

  void _openFuelLogSheet() {
    if (_vehicles.isEmpty) {
      showAppSnackbar(
        context,
        message: 'Add a vehicle first before logging fuel.',
        isError: true,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FuelLogSheet(
        user: _user!,
        vehicles: _vehicles,
        onSaved: () {
          _loadFuelData();
        },
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextSub
                    : AppColors.lightTextSub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '/login');
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _user;

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
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Top bar ───────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: _buildTopBar(isDark, user),
                    ),
                  ),
                  // ── Welcome card ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: KeyedSubtree(
                        key: _keyWelcome,
                        child: _buildWelcomeCard(isDark, user),
                      ),
                    ),
                  ),
                  // ── Stats row ─────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: _buildStatsRow(isDark),
                    ),
                  ),
                  // ── Wallet preview ────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                      child: KeyedSubtree(
                        key: _keyWallet,
                        child: _buildWalletPreview(isDark),
                      ),
                    ),
                  ),
                  // ── My Vehicles ───────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: KeyedSubtree(
                        key: _keyVehicles,
                        child: _buildVehiclesSection(isDark),
                      ),
                    ),
                  ),
                  // ── Quick Actions ─────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
                      child: KeyedSubtree(
                        key: _keyActions,
                        child: Text(
                          'Quick Actions',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.1,
                          ),
                      delegate: SliverChildListDelegate([
                        _ActionCard(
                          icon: Icons.local_gas_station_rounded,
                          label: 'Fuel Log',
                          sublabel: 'Track refuels',
                          gradient: [AppColors.emerald, AppColors.emeraldDark],
                          isDark: isDark,
                          onTap: _openFuelLogSheet,
                        ),
                        _ActionCard(
                          icon: Icons.bar_chart_rounded,
                          label: 'Analytics',
                          sublabel: 'View reports',
                          gradient: [AppColors.ocean, AppColors.oceanDark],
                          isDark: isDark,
                          onTap: () {},
                        ),
                        _ActionCard(
                          icon: Icons.route_rounded,
                          label: 'Trips',
                          sublabel: 'Manage routes',
                          gradient: [AppColors.amber, AppColors.amberDark],
                          isDark: isDark,
                          onTap: () {},
                        ),
                        _ActionCard(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Top Up',
                          sublabel: 'Add fuel credits',
                          gradient: [
                            const Color(0xFF7C3AED),
                            const Color(0xFF0A84FF),
                          ],
                          isDark: isDark,
                          onTap: _goToTopUp,
                        ),
                      ]),
                    ),
                  ),
                  // ── Recent Activity ───────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
                      child: Row(
                        children: [
                          Text(
                            'Recent Fuel Logs',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const Spacer(),
                          if (_recentLogs.isNotEmpty)
                            GestureDetector(
                              onTap: _openFuelLogSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: AppColors.emerald.withOpacity(
                                    isDark ? 0.12 : 0.08,
                                  ),
                                  border: Border.all(
                                    color: AppColors.emerald.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.add_rounded,
                                      size: 13,
                                      color: AppColors.emerald,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Add Log',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.emerald,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                      child: _recentLogs.isEmpty
                          ? _buildEmptyActivity(isDark)
                          : _buildRecentLogs(isDark),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!_showTour) return screen;

    return SpotlightTour(
      steps: [
        TourStep(
          targetKey: _keyWelcome,
          title: 'Your Dashboard',
          body:
              'This is your home screen. See your greeting, NIC, '
              'and email at a glance.',
          icon: Icons.dashboard_rounded,
          gradient: [AppColors.emerald, AppColors.ocean],
          position: TooltipPosition.below,
        ),
        TourStep(
          targetKey: _keyWallet,
          title: 'Fuelix Wallet',
          body:
              'Your wallet balance is shown here. '
              'Tap to top up and manage your fuel credits.',
          icon: Icons.account_balance_wallet_rounded,
          gradient: [const Color(0xFF7C3AED), const Color(0xFF0A84FF)],
          position: TooltipPosition.below,
        ),
        TourStep(
          targetKey: _keyVehicles,
          title: 'My Vehicles',
          body:
              'Add and manage your vehicles here. '
              'Each vehicle gets a unique Fuel Pass QR code.',
          icon: Icons.directions_car_rounded,
          gradient: [AppColors.ocean, AppColors.emerald],
          position: TooltipPosition.below,
        ),
        TourStep(
          targetKey: _keyActions,
          title: 'Quick Actions',
          body:
              'Log fuel, view analytics, manage trips, '
              'and top up your wallet — all from here.',
          icon: Icons.grid_view_rounded,
          gradient: [AppColors.amber, AppColors.emerald],
          position: TooltipPosition.above,
        ),
      ],
      onComplete: () async {
        await TutorialService.markSeen(TutorialKey.homeTour);
        if (mounted) setState(() => _showTour = false);
      },
      child: screen,
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(bool isDark, UserModel? user) {
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
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isDark
                ? AppColors.darkSurfaceAlt
                : AppColors.lightSurfaceAlt,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Icon(
            Icons.notifications_outlined,
            size: 18,
            color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, '/profile', arguments: user),
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
                user != null ? user.firstName[0].toUpperCase() : 'U',
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

  // ── Welcome card ──────────────────────────────────────────────────────────
  Widget _buildWelcomeCard(bool isDark, UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.emerald, AppColors.ocean],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.fullName ?? 'User',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.15),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 8,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Active',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.badge_outlined,
                size: 14,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Text(
                'NIC: ${user?.nic ?? 'N/A'}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.email_outlined,
                size: 14,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  user?.email ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow(bool isDark) {
    final totalLogs = _stats['total_logs']?.toInt() ?? 0;
    final totalLitres = _stats['total_litres'] ?? 0.0;
    final totalKm = _stats['total_km'] ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Logs',
            value: '$totalLogs',
            icon: Icons.list_alt_rounded,
            color: AppColors.emerald,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Fuel Used',
            value: '${totalLitres.toStringAsFixed(1)} L',
            icon: Icons.local_gas_station_rounded,
            color: AppColors.ocean,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Total Km',
            value: '${totalKm.toStringAsFixed(0)} km',
            icon: Icons.speed_rounded,
            color: AppColors.amber,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // ── Wallet preview mini-card ──────────────────────────────────────────────
  Widget _buildWalletPreview(bool isDark) {
    return GestureDetector(
      onTap: _goToTopUp,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF0A84FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.18),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 19,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fuelix Wallet',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    _wallet != null ? _wallet!.formattedBalance : 'LKR 0.00',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Top Up',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

  // ── Vehicles section ──────────────────────────────────────────────────────
  Widget _buildVehiclesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'My Vehicles',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            GestureDetector(
              onTap: _goToVehicles,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.emerald.withOpacity(isDark ? 0.12 : 0.08),
                  border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Manage',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: AppColors.emerald,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_vehicles.isEmpty)
          _VehicleEmptyCard(isDark: isDark, onAdd: _goToVehicles)
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _vehicles.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                if (i == _vehicles.length) {
                  return _VehicleAddCard(isDark: isDark, onTap: _goToVehicles);
                }
                return _VehicleChip(vehicle: _vehicles[i], isDark: isDark);
              },
            ),
          ),
      ],
    );
  }

  // ── Recent Fuel Logs ──────────────────────────────────────────────────────
  Widget _buildRecentLogs(bool isDark) {
    return Column(
      children: _recentLogs.map((log) {
        final vehicle = _vehicles.firstWhere(
          (v) => v.id == log.vehicleId,
          orElse: () => VehicleModel(
            userId: log.userId,
            type: 'Car',
            make: 'Unknown',
            model: '',
            year: '',
            registrationNo: '',
            fuelType: log.fuelType,
          ),
        );
        return _FuelLogTile(
          log: log,
          vehicle: vehicle,
          isDark: isDark,
          onDelete: () async {
            if (log.id == null) return;
            await _db.deleteFuelLog(log.id!);
            _loadFuelData();
          },
        );
      }).toList(),
    );
  }

  // ── Empty activity ────────────────────────────────────────────────────────
  Widget _buildEmptyActivity(bool isDark) {
    return GestureDetector(
      onTap: _openFuelLogSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border.all(
            color: AppColors.emerald.withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emerald.withOpacity(isDark ? 0.12 : 0.08),
              ),
              child: const Icon(
                Icons.local_gas_station_rounded,
                size: 26,
                color: AppColors.emerald,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No fuel logs yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap here to log your first refuel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [AppColors.emerald, AppColors.ocean],
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'Add Fuel Log',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Fuel Log Tile
// ═════════════════════════════════════════════════════════════════════════════
class _FuelLogTile extends StatelessWidget {
  final FuelLogModel log;
  final VehicleModel vehicle;
  final bool isDark;
  final VoidCallback onDelete;

  const _FuelLogTile({
    required this.log,
    required this.vehicle,
    required this.isDark,
    required this.onDelete,
  });

  Color _fuelColor(String type) {
    switch (type) {
      case 'Diesel':
        return AppColors.amber;
      case 'Electric':
        return AppColors.emerald;
      case 'LPG':
        return const Color(0xFFF97316);
      default:
        return AppColors.ocean;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _fuelColor(log.fuelType);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                'Delete Log',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              content: Text(
                'Remove this fuel log entry?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.spaceGrotesk(
                      color: isDark
                          ? AppColors.darkTextSub
                          : AppColors.lightTextSub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onDelete();
                  },
                  child: Text(
                    'Delete',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: accent.withOpacity(isDark ? 0.14 : 0.10),
                ),
                child: Icon(
                  Icons.local_gas_station_rounded,
                  size: 22,
                  color: accent,
                ),
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
                            vehicle.shortDisplay,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${log.litres.toStringAsFixed(1)} L',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: accent.withOpacity(isDark ? 0.15 : 0.10),
                          ),
                          child: Text(
                            log.fuelType,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            log.stationName.isNotEmpty
                                ? log.stationName
                                : 'Unknown station',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSub
                                  : AppColors.lightTextSub,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          log.totalCost > 0
                              ? 'LKR ${log.totalCost.toStringAsFixed(0)}'
                              : '',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${log.formattedDate} · ${log.formattedTime}'
                      '${log.odometerKm > 0 ? ' · ${log.odometerKm.toStringAsFixed(0)} km' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
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
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Fuel Log Bottom Sheet
// ═════════════════════════════════════════════════════════════════════════════
class _FuelLogSheet extends StatefulWidget {
  final UserModel user;
  final List<VehicleModel> vehicles;
  final VoidCallback onSaved;

  const _FuelLogSheet({
    required this.user,
    required this.vehicles,
    required this.onSaved,
  });

  @override
  State<_FuelLogSheet> createState() => _FuelLogSheetState();
}

class _FuelLogSheetState extends State<_FuelLogSheet> {
  final _formKey = GlobalKey<FormState>();
  final _db = DbHelper();

  late VehicleModel _selectedVehicle;
  final _litresCtrl = TextEditingController();
  final _odometerCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isSaving = false;
  double _totalCost = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedVehicle = widget.vehicles.first;
    _litresCtrl.addListener(_recalcCost);
    _priceCtrl.addListener(_recalcCost);
  }

  @override
  void dispose() {
    _litresCtrl.removeListener(_recalcCost);
    _priceCtrl.removeListener(_recalcCost);
    _litresCtrl.dispose();
    _odometerCtrl.dispose();
    _priceCtrl.dispose();
    _stationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _recalcCost() {
    final litres = double.tryParse(_litresCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    setState(() => _totalCost = litres * price);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final log = FuelLogModel(
      userId: widget.user.id!,
      vehicleId: _selectedVehicle.id!,
      litres: double.parse(_litresCtrl.text),
      odometerKm: double.tryParse(_odometerCtrl.text) ?? 0.0,
      fuelType: _selectedVehicle.fuelType,
      pricePerLitre: double.tryParse(_priceCtrl.text) ?? 0.0,
      totalCost: _totalCost,
      stationName: _stationCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      loggedAt: DateTime.now(),
    );

    final id = await _db.insertFuelLog(log);
    if (mounted) {
      setState(() => _isSaving = false);
      if (id > 0) {
        widget.onSaved();
        Navigator.pop(context);
        showAppSnackbar(
          context,
          message: 'Fuel log saved successfully!',
          isSuccess: true,
        );
      } else {
        showAppSnackbar(
          context,
          message: 'Failed to save log. Please try again.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkBackground
                : AppColors.lightBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [AppColors.emerald, AppColors.ocean],
                        ),
                      ),
                      child: const Icon(
                        Icons.local_gas_station_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Log Fuel',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            'Record a refuel for your vehicle',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextSub
                                      : AppColors.lightTextSub,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark
                            ? AppColors.darkTextSub
                            : AppColors.lightTextSub,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Divider(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                height: 1,
              ),
              // Form
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vehicle selector
                        Text(
                          'Vehicle',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextSub
                                : AppColors.lightTextSub,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: isDark
                                ? AppColors.darkSurface
                                : AppColors.lightSurface,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                              width: 1.5,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<VehicleModel>(
                              value: _selectedVehicle,
                              isExpanded: true,
                              borderRadius: BorderRadius.circular(14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              dropdownColor: isDark
                                  ? AppColors.darkSurfaceAlt
                                  : AppColors.lightSurface,
                              items: widget.vehicles
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(
                                        '${v.shortDisplay} · ${v.registrationNo}',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: isDark
                                              ? AppColors.darkText
                                              : AppColors.lightText,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedVehicle = v);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Fuel type badge
                        Row(
                          children: [
                            Icon(
                              Icons.local_gas_station_rounded,
                              size: 14,
                              color: isDark
                                  ? AppColors.darkTextSub
                                  : AppColors.lightTextSub,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Fuel Type: ',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.darkTextSub
                                    : AppColors.lightTextSub,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: AppColors.emerald.withOpacity(
                                  isDark ? 0.14 : 0.10,
                                ),
                              ),
                              child: Text(
                                _selectedVehicle.fuelType,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.emerald,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Litres
                        AppTextField(
                          label: 'Litres Filled',
                          hint: 'e.g. 10.5',
                          controller: _litresCtrl,
                          prefixIcon: Icons.opacity_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Litres is required';
                            }
                            final d = double.tryParse(v.trim());
                            if (d == null || d <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Price per litre
                        AppTextField(
                          label: 'Price per Litre (LKR)',
                          hint: 'e.g. 320.00',
                          controller: _priceCtrl,
                          prefixIcon: Icons.payments_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Odometer
                        AppTextField(
                          label: 'Odometer Reading (km)',
                          hint: 'e.g. 45230',
                          controller: _odometerCtrl,
                          prefixIcon: Icons.speed_rounded,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Station name
                        AppTextField(
                          label: 'Station Name',
                          hint: 'e.g. CPC Colombo 7',
                          controller: _stationCtrl,
                          prefixIcon: Icons.place_outlined,
                        ),
                        const SizedBox(height: 14),

                        // Notes
                        AppTextField(
                          label: 'Notes (optional)',
                          hint: 'Any additional notes…',
                          controller: _notesCtrl,
                          prefixIcon: Icons.notes_rounded,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),

                        // Total cost preview
                        if (_totalCost > 0)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.emerald.withOpacity(0.12),
                                  AppColors.ocean.withOpacity(0.10),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.emerald.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calculate_outlined,
                                  size: 20,
                                  color: AppColors.emerald,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Estimated total cost',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.darkTextSub
                                          : AppColors.lightTextSub,
                                    ),
                                  ),
                                ),
                                Text(
                                  'LKR ${_totalCost.toStringAsFixed(2)}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.emerald,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Save button
                        GradientButton(
                          label: 'Save Fuel Log',
                          onPressed: _save,
                          isLoading: _isSaving,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Stat Card
// ═════════════════════════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Action Card
// ═════════════════════════════════════════════════════════════════════════════
class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String label, sublabel;
  final List<Color> gradient;
  final bool isDark;
  final VoidCallback onTap;
  final Color? labelColor, sublabelColor, iconColor;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradient,
    required this.isDark,
    required this.onTap,
    this.labelColor,
    this.sublabelColor,
    this.iconColor,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isColored = widget.labelColor == null;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isColored
                ? LinearGradient(
                    colors: widget.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isColored
                ? null
                : (widget.isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface),
            border: !isColored
                ? Border.all(
                    color: widget.isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  )
                : null,
            boxShadow: isColored
                ? [
                    BoxShadow(
                      color: widget.gradient.first.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isColored
                      ? Colors.white.withOpacity(0.2)
                      : widget.gradient.first.withOpacity(0.12),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color:
                      widget.iconColor ??
                      (isColored ? Colors.white : widget.gradient.first),
                ),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: widget.labelColor ?? Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.sublabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color:
                          widget.sublabelColor ??
                          Colors.white.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Vehicle chip (horizontal list item) ─────────────────────────────────────
class _VehicleChip extends StatelessWidget {
  final VehicleModel vehicle;
  final bool isDark;
  const _VehicleChip({required this.vehicle, required this.isDark});

  Color _accent(String type) {
    switch (type) {
      case 'Car':
        return AppColors.ocean;
      case 'Motorcycle':
        return AppColors.amber;
      case 'Van':
        return AppColors.emerald;
      case 'Truck':
        return const Color(0xFFEF4444);
      case 'Bus':
        return const Color(0xFF7C3AED);
      case 'Three-Wheeler':
        return const Color(0xFFF97316);
      default:
        return AppColors.emerald;
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'Car':
        return Icons.directions_car_rounded;
      case 'Motorcycle':
        return Icons.two_wheeler_rounded;
      case 'Van':
        return Icons.airport_shuttle_rounded;
      case 'Truck':
        return Icons.local_shipping_rounded;
      case 'Bus':
        return Icons.directions_bus_rounded;
      case 'Three-Wheeler':
        return Icons.electric_rickshaw_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(vehicle.type);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: LinearGradient(
                    colors: [accent, accent.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(_icon(vehicle.type), size: 16, color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: accent.withOpacity(isDark ? 0.15 : 0.10),
                ),
                child: Text(
                  vehicle.fuelType,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.shortDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                vehicle.registrationNo,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Add vehicle card ─────────────────────────────────────────────────────────
class _VehicleAddCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _VehicleAddCard({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border.all(
            color: AppColors.emerald.withOpacity(0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emerald.withOpacity(isDark ? 0.15 : 0.10),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 20,
                color: AppColors.emerald,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.emerald,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty vehicle card ───────────────────────────────────────────────────────
class _VehicleEmptyCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback onAdd;
  const _VehicleEmptyCard({required this.isDark, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border.all(
            color: AppColors.emerald.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    AppColors.emerald.withOpacity(0.15),
                    AppColors.ocean.withOpacity(0.15),
                  ],
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 22,
                color: AppColors.emerald,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add your first vehicle',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Tap to add a car, bike or any vehicle',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSub
                          : AppColors.lightTextSub,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.emerald,
            ),
          ],
        ),
      ),
    );
  }
}
