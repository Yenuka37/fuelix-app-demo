import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/topup_model.dart';
import '../models/fuel_log_model.dart';
import '../models/quota_model.dart';
import '../services/api_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/tutorial_overlay.dart';
import 'fuel_stations_screen.dart';

// ─── Fuel grade catalogue ─────────────────────────────────────────────────────
class FuelGrade {
  final String name;
  final double pricePerLitre;
  const FuelGrade(this.name, this.pricePerLitre);
}

class FuelCatalogue {
  static const List<FuelGrade> petrolGrades = [
    FuelGrade('Petrol 92', 317),
    FuelGrade('Petrol 95', 365),
  ];

  static const List<FuelGrade> dieselGrades = [
    FuelGrade('Auto Diesel', 303),
    FuelGrade('Super Diesel', 353),
  ];

  static const List<FuelGrade> keroseneGrades = [FuelGrade('Kerosene', 195)];

  static List<FuelGrade> gradesFor(String fuelType) {
    final f = fuelType.toLowerCase();
    final List<FuelGrade> result = [];
    if (f == 'petrol' || f == 'hybrid') result.addAll(petrolGrades);
    if (f == 'diesel' || f == 'hybrid') result.addAll(dieselGrades);
    if (f == 'kerosene') result.addAll(keroseneGrades);
    return result;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HomeScreen
// ═════════════════════════════════════════════════════════════════════════════
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
    'total_spent': 0,
  };
  final _apiService = ApiService();

  // Tutorial keys
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
    final result = await _apiService.getVehicles(_user!.id!);
    if (result['success']) {
      List<dynamic> jsonList = result['data'];
      List<VehicleModel> vehicles = jsonList
          .map(
            (json) => VehicleModel(
              id: json['id'],
              userId: json['userId'],
              type: json['type'],
              make: json['make'],
              model: json['model'],
              year: json['year'],
              registrationNo: json['registrationNo'],
              fuelType: json['fuelType'],
              engineCC: json['engineCC'] ?? '',
              color: json['color'] ?? '',
              fuelPassCode: json['fuelPassCode'],
              qrGeneratedAt: json['qrGeneratedAt'] != null
                  ? DateTime.tryParse(json['qrGeneratedAt'])
                  : null,
              createdAt: json['createdAt'] != null
                  ? DateTime.tryParse(json['createdAt'])
                  : null,
            ),
          )
          .toList();
      if (mounted) setState(() => _vehicles = vehicles);
    } else {
      if (mounted) setState(() => _vehicles = []);
    }
  }

  Future<void> _loadWallet() async {
    if (_user?.id == null) return;
    final result = await _apiService.getWallet(_user!.id!);
    if (result['success']) {
      final data = result['data'];
      final wallet = WalletModel(
        userId: _user!.id!,
        balance: data['balance'],
        updatedAt: DateTime.tryParse(data['updatedAt']),
      );
      if (mounted) setState(() => _wallet = wallet);
    } else {
      if (mounted) setState(() => _wallet = null);
    }
  }

  Future<void> _loadFuelData() async {
    if (_user?.id == null) return;

    // Load stats from backend
    final statsResult = await _apiService.getFuelLogStats(_user!.id!);
    if (statsResult['success']) {
      final stats = statsResult['data'];
      if (mounted) {
        setState(() {
          _stats = {
            'total_logs': stats['totalLogs']?.toDouble() ?? 0,
            'total_litres': stats['totalLitres'] ?? 0,
            'total_spent': stats['totalSpent'] ?? 0,
          };
        });
      }
    }

    // Load recent logs
    final logsResult = await _apiService.getUserFuelLogs(_user!.id!);
    if (logsResult['success']) {
      List<dynamic> logsJson = logsResult['data'];
      List<FuelLogModel> logs = logsJson
          .map(
            (json) => FuelLogModel(
              id: json['id'],
              userId: json['userId'],
              vehicleId: json['vehicleId'],
              litres: json['litres'],
              fuelType: json['fuelType'],
              fuelGrade: json['fuelGrade'],
              pricePerLitre: json['pricePerLitre'],
              totalCost: json['totalCost'],
              stationName: json['stationName'] ?? '',
              loggedAt: DateTime.parse(json['loggedAt']),
            ),
          )
          .toList();
      if (mounted) setState(() => _recentLogs = logs);
    } else {
      if (mounted) setState(() => _recentLogs = []);
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

  void _goToFuelStations() {
    Navigator.pushNamed(context, '/fuel_stations', arguments: _user);
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
        walletBalance: _wallet?.balance ?? 0.0,
        onSaved: () {
          _loadAll();
        },
        apiService: _apiService,
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: _buildTopBar(isDark, user),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: KeyedSubtree(
                        key: _keyWelcome,
                        child: _buildWelcomeCard(isDark, user),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: _buildStatsRow(isDark),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                      child: KeyedSubtree(
                        key: _keyWallet,
                        child: _buildWalletPreview(isDark),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: KeyedSubtree(
                        key: _keyVehicles,
                        child: _buildVehiclesSection(isDark),
                      ),
                    ),
                  ),
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
                          icon: Icons.local_gas_station_outlined,
                          label: 'Fuel Stations',
                          sublabel: 'Find nearby',
                          gradient: [AppColors.amber, AppColors.amberDark],
                          isDark: isDark,
                          onTap: _goToFuelStations,
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
                  // Recent Fuel Logs
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
              'Log fuel, view analytics, find fuel stations, '
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
    final totalLogs = (_stats['total_logs'] ?? 0).toInt();
    final totalLitres = _stats['total_litres'] ?? 0.0;
    final totalSpent = _stats['total_spent'] ?? 0.0;

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
            label: 'Total Spent',
            value: 'Rs. ${totalSpent.toStringAsFixed(0)}',
            icon: Icons.payments_outlined,
            color: AppColors.amber,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // ── Wallet preview ────────────────────────────────────────────────────────
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

  // ── Recent Fuel Logs list ─────────────────────────────────────────────────
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
            final result = await _apiService.deleteFuelLog(log.id!);
            if (result['success']) {
              _loadFuelData();
              showAppSnackbar(context, message: 'Log deleted', isSuccess: true);
            } else {
              showAppSnackbar(context, message: result['error'], isError: true);
            }
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

  Color _gradeColor(String grade) {
    if (grade.contains('95')) return const Color(0xFF7C3AED);
    if (grade.contains('92')) return AppColors.ocean;
    if (grade.contains('Super')) return AppColors.amber;
    if (grade.contains('Auto')) return const Color(0xFFF97316);
    if (grade.contains('Kerosene')) return const Color(0xFF6B7280);
    return AppColors.emerald;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _gradeColor(log.fuelGrade);
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
                            log.fuelGrade,
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
                              ? 'Rs. ${log.totalCost.toStringAsFixed(0)}'
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
                      '${log.formattedDate} · ${log.formattedTime}',
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
  final double walletBalance;
  final VoidCallback onSaved;
  final ApiService apiService;

  const _FuelLogSheet({
    required this.user,
    required this.vehicles,
    required this.walletBalance,
    required this.onSaved,
    required this.apiService,
  });

  @override
  State<_FuelLogSheet> createState() => _FuelLogSheetState();
}

class _FuelLogSheetState extends State<_FuelLogSheet> {
  final _formKey = GlobalKey<FormState>();

  late VehicleModel _selectedVehicle;
  FuelGrade? _selectedGrade;
  List<FuelGrade> _availableGrades = [];

  final _litresCtrl = TextEditingController();
  final _stationCtrl = TextEditingController();

  bool _isSaving = false;
  double _quotaRemaining = 0;
  double _walletBalance = 0;
  bool _limitsLoaded = false;

  double get _maxLitres {
    if (_selectedGrade == null) return _quotaRemaining;
    final walletLitres = _walletBalance / _selectedGrade!.pricePerLitre;
    return _quotaRemaining < walletLitres ? _quotaRemaining : walletLitres;
  }

  double get _totalCost {
    final litres = double.tryParse(_litresCtrl.text) ?? 0;
    return litres * (_selectedGrade?.pricePerLitre ?? 0);
  }

  @override
  void initState() {
    super.initState();
    _selectedVehicle = widget.vehicles.first;
    _walletBalance = widget.walletBalance;
    _litresCtrl.addListener(() => setState(() {}));
    _refreshGradesAndLimits();
  }

  @override
  void dispose() {
    _litresCtrl.dispose();
    _stationCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshGradesAndLimits() async {
    setState(() => _limitsLoaded = false);

    final grades = FuelCatalogue.gradesFor(_selectedVehicle.fuelType);
    final quotaResult = await widget.apiService.getCurrentQuota(
      _selectedVehicle.id!,
      _selectedVehicle.type,
    );

    double remaining = 0;
    if (quotaResult['success']) {
      remaining = quotaResult['data']['remainingLitres']?.toDouble() ?? 0;
    }

    if (!mounted) return;
    setState(() {
      _availableGrades = grades;
      _selectedGrade = grades.isNotEmpty ? grades.first : null;
      _quotaRemaining = remaining;
      _limitsLoaded = true;
      _litresCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGrade == null) return;

    setState(() => _isSaving = true);

    final litres = double.parse(_litresCtrl.text.trim());
    final cost = litres * _selectedGrade!.pricePerLitre;

    final logData = {
      'userId': widget.user.id!,
      'vehicleId': _selectedVehicle.id!,
      'litres': litres,
      'fuelType': _selectedVehicle.fuelType,
      'fuelGrade': _selectedGrade!.name,
      'pricePerLitre': _selectedGrade!.pricePerLitre,
      'totalCost': cost,
      'stationName': _stationCtrl.text.trim(),
      'vehicleType': _selectedVehicle.type,
    };

    final result = await widget.apiService.addFuelLog(logData);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success']) {
      widget.onSaved();
      Navigator.pop(context);
      showAppSnackbar(
        context,
        message: 'Fuel log saved successfully!',
        isSuccess: true,
      );
    } else if (result['error'].contains('quota')) {
      showAppSnackbar(
        context,
        message:
            'Exceeds your weekly fuel quota. Max: ${_quotaRemaining.toStringAsFixed(1)} L',
        isError: true,
      );
    } else if (result['error'].contains('balance')) {
      showAppSnackbar(
        context,
        message: 'Insufficient wallet balance. Top up to continue.',
        isError: true,
      );
    } else {
      showAppSnackbar(
        context,
        message: 'Failed to save log. Please try again.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
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
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Vehicle selector ──────────────────────────────
                        _sectionLabel('Vehicle', isDark),
                        const SizedBox(height: 8),
                        _dropdown<VehicleModel>(
                          isDark: isDark,
                          value: _selectedVehicle,
                          items: widget.vehicles,
                          itemLabel: (v) =>
                              '${v.shortDisplay} · ${v.registrationNo}',
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => _selectedVehicle = v);
                            await _refreshGradesAndLimits();
                          },
                        ),
                        const SizedBox(height: 20),

                        // ── Quota + wallet info bar ───────────────────────
                        if (_limitsLoaded)
                          _buildLimitsBar(isDark)
                        else
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.emerald,
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),

                        // ── Fuel grade selector ───────────────────────────
                        if (_availableGrades.isEmpty) ...[
                          _buildUnsupportedFuelNote(isDark),
                        ] else ...[
                          _sectionLabel('Fuel Grade', isDark),
                          const SizedBox(height: 10),
                          _buildGradeSelector(isDark),
                          const SizedBox(height: 20),

                          // ── Litres field ──────────────────────────────
                          _sectionLabel('Litres Filled', isDark),
                          const SizedBox(height: 8),
                          _buildLitresField(isDark),
                          const SizedBox(height: 20),

                          // ── Station name ──────────────────────────────
                          AppTextField(
                            label: 'Station Name (optional)',
                            hint: 'e.g. CPC Colombo 7',
                            controller: _stationCtrl,
                            prefixIcon: Icons.place_outlined,
                          ),
                          const SizedBox(height: 20),

                          // ── Cost preview ──────────────────────────────
                          if (_totalCost > 0) _buildCostPreview(isDark),
                          const SizedBox(height: 8),

                          // ── Save button ───────────────────────────────
                          GradientButton(
                            label: 'Save Fuel Log',
                            onPressed: (_limitsLoaded && _maxLitres > 0)
                                ? _save
                                : null,
                            isLoading: _isSaving,
                          ),
                        ],
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

  // ── Quota + wallet limits bar ─────────────────────────────────────────────
  Widget _buildLimitsBar(bool isDark) {
    final effectiveMax = _maxLitres;

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
        children: [
          _limitRow(
            icon: Icons.local_gas_station_rounded,
            label: 'Weekly quota remaining',
            value: '${_quotaRemaining.toStringAsFixed(1)} L',
            color: _quotaRemaining > 0 ? AppColors.emerald : AppColors.error,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _limitRow(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Wallet balance',
            value: 'Rs. ${_walletBalance.toStringAsFixed(2)}',
            color: _walletBalance > 0 ? AppColors.ocean : AppColors.error,
            isDark: isDark,
          ),
          if (_selectedGrade != null) ...[
            const SizedBox(height: 10),
            _limitRow(
              icon: Icons.straighten_rounded,
              label: 'Max you can fill now',
              value: effectiveMax > 0
                  ? '${effectiveMax.toStringAsFixed(1)} L'
                  : 'Top up wallet or wait for quota reset',
              color: effectiveMax > 0 ? AppColors.amber : AppColors.error,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _limitRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ── Grade selector ────────────────────────────────────────────────────────
  Widget _buildGradeSelector(bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _availableGrades.map((grade) {
        final isSelected = _selectedGrade?.name == grade.name;
        Color accent = _gradeAccent(grade.name);
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedGrade = grade;
              _litresCtrl.clear();
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isSelected
                  ? LinearGradient(
                      colors: [accent, accent.withOpacity(0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected
                  ? null
                  : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
              border: Border.all(
                color: isSelected
                    ? accent
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: isSelected ? 0 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accent.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grade.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.darkText : AppColors.lightText),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rs. ${grade.pricePerLitre.toStringAsFixed(0)}/L',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isSelected
                        ? Colors.white.withOpacity(0.85)
                        : (isDark
                              ? AppColors.darkTextSub
                              : AppColors.lightTextSub),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Litres field with live validation ─────────────────────────────────────
  Widget _buildLitresField(bool isDark) {
    final max = _maxLitres;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _litresCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            labelText: 'Litres',
            hintText: max > 0
                ? 'Max ${max.toStringAsFixed(1)} L'
                : 'No quota or balance available',
            prefixIcon: const Icon(Icons.opacity_rounded, size: 20),
            suffixText: 'L',
            suffixStyle: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Litres is required';
            final d = double.tryParse(v.trim());
            if (d == null || d <= 0) return 'Enter a valid amount';
            if (d > max + 0.001) {
              return 'Max allowed: ${max.toStringAsFixed(1)} L '
                  '(quota or wallet limit)';
            }
            return null;
          },
        ),
        if (_litresCtrl.text.isNotEmpty && max > 0) ...[
          const SizedBox(height: 8),
          _buildLitresProgressBar(isDark, max),
        ],
      ],
    );
  }

  Widget _buildLitresProgressBar(bool isDark, double max) {
    final entered = double.tryParse(_litresCtrl.text) ?? 0;
    final ratio = (entered / max).clamp(0.0, 1.0);
    final overLimit = entered > max + 0.001;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: isDark
                ? AppColors.darkBorder
                : AppColors.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(
              overLimit
                  ? AppColors.error
                  : ratio > 0.85
                  ? AppColors.amber
                  : AppColors.emerald,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          overLimit
              ? 'Exceeds limit'
              : '${entered.toStringAsFixed(1)} / ${max.toStringAsFixed(1)} L',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: overLimit
                ? AppColors.error
                : isDark
                ? AppColors.darkTextMuted
                : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }

  // ── Cost preview ──────────────────────────────────────────────────────────
  Widget _buildCostPreview(bool isDark) {
    final cost = _totalCost;
    final affordable = cost <= _walletBalance + 0.001;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: affordable
              ? [
                  AppColors.emerald.withOpacity(0.12),
                  AppColors.ocean.withOpacity(0.10),
                ]
              : [
                  AppColors.error.withOpacity(0.10),
                  AppColors.error.withOpacity(0.06),
                ],
        ),
        border: Border.all(
          color: affordable
              ? AppColors.emerald.withOpacity(0.25)
              : AppColors.error.withOpacity(0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                affordable
                    ? Icons.calculate_outlined
                    : Icons.warning_amber_rounded,
                size: 20,
                color: affordable ? AppColors.emerald : AppColors.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  affordable
                      ? 'Estimated total cost'
                      : 'Insufficient wallet balance',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: affordable
                        ? (isDark
                              ? AppColors.darkTextSub
                              : AppColors.lightTextSub)
                        : AppColors.error,
                  ),
                ),
              ),
              Text(
                'Rs. ${cost.toStringAsFixed(2)}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: affordable ? AppColors.emerald : AppColors.error,
                ),
              ),
            ],
          ),
          if (!affordable) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 30),
                Expanded(
                  child: Text(
                    'Wallet: Rs. ${_walletBalance.toStringAsFixed(2)}  ·  '
                    'Shortfall: Rs. ${(cost - _walletBalance).toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Unsupported fuel note ─────────────────────────────────────────────────
  Widget _buildUnsupportedFuelNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(color: AppColors.amber.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.amber,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Fuel logging is not available for '
              '${_selectedVehicle.fuelType} vehicles '
              '(Electric / LPG).',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color _gradeAccent(String name) {
    if (name.contains('95')) return const Color(0xFF7C3AED);
    if (name.contains('92')) return AppColors.ocean;
    if (name.contains('Super')) return AppColors.amber;
    if (name.contains('Auto')) return const Color(0xFFF97316);
    return const Color(0xFF6B7280);
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
      ),
    );
  }

  Widget _dropdown<T>({
    required bool isDark,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          dropdownColor: isDark
              ? AppColors.darkSurfaceAlt
              : AppColors.lightSurface,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabel(item),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
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

// ─── Vehicle chip ─────────────────────────────────────────────────────────────
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
