import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/topup_model.dart';
import '../models/fuel_log_model.dart';
import '../services/api_service.dart';
import '../services/notification_local_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/tutorial_overlay.dart';
import 'fuel_stations_screen.dart';
import 'fuel_log_screen.dart';
import 'notifications_screen.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Bell animation controllers - only created when needed
  AnimationController? _bellController;
  Animation<double>? _bellRotation;

  // Counter animation
  late AnimationController _counterController;
  late Animation<double> _counterScale;

  UserModel? _user;
  List<VehicleModel> _vehicles = [];
  WalletModel? _wallet;
  List<FuelLogModel> _recentLogs = [];
  Map<String, double> _stats = {
    'total_logs': 0,
    'total_litres': 0,
    'total_spent': 0,
  };
  int _unreadCount = 0;
  final ApiService _apiService = ApiService();
  final NotificationLocalService _localService = NotificationLocalService();

  final _keyWelcome = GlobalKey();
  final _keyVehicles = GlobalKey();
  final _keyWallet = GlobalKey();
  final _keyActions = GlobalKey();
  final _keyFuelLogAction = GlobalKey();
  final _keyNotifications = GlobalKey();
  bool _showTour = false;

  @override
  void initState() {
    super.initState();

    // Main animation controllers
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    // Counter animation (always needed)
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _counterScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _counterController, curve: Curves.elasticOut),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animController.forward();
    });
  }

  // Initialize bell animation only when there are unread notifications
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

  // Dispose bell animation if it exists
  void _disposeBellAnimation() {
    if (_bellController != null) {
      _bellController!.dispose();
      _bellController = null;
      _bellRotation = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is UserModel && _user?.id != args.id) {
      _user = args;
      _loadAll();
      _checkHomeTour();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _counterController.dispose();
    _disposeBellAnimation();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadVehicles(),
      _loadWallet(),
      _loadFuelData(),
      _loadUnreadCount(),
    ]);
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

  Future<void> _loadUnreadCount() async {
    if (_user?.id == null) return;

    try {
      final result = await _apiService.getUserNotifications(_user!.id!);

      if (result['success'] && mounted) {
        final List<dynamic> notificationsJson = result['data'] ?? [];

        final List<int> notificationIds = [];
        for (var json in notificationsJson) {
          if (json is Map<String, dynamic>) {
            notificationIds.add(json['id'] as int);
          }
        }

        final readStatusMap = await _localService.getReadStatus(
          notificationIds,
        );

        int unread = 0;
        for (var json in notificationsJson) {
          if (json is Map<String, dynamic>) {
            final notificationId = json['id'] as int;
            final isRead = readStatusMap[notificationId] ?? false;
            if (!isRead) {
              unread++;
            }
          }
        }

        final bool hadUnreadBefore = _unreadCount > 0;
        final bool hasUnreadNow = unread > 0;

        // Handle bell animation based on unread status
        if (hasUnreadNow && !hadUnreadBefore) {
          // New unread notifications appeared - start animation
          _initBellAnimation();
          _counterController.forward(from: 0);
        } else if (!hasUnreadNow && hadUnreadBefore) {
          // All notifications read - stop and dispose animation
          _disposeBellAnimation();
        } else if (hasUnreadNow && _bellController == null) {
          // Still have unread but animation not running - start it
          _initBellAnimation();
        }

        setState(() {
          _unreadCount = unread;
        });
      }
    } catch (e) {
      print('Error loading unread count: $e');
    }
  }

  void _goToVehicles() async {
    final result = await Navigator.pushNamed(
      context,
      '/vehicles',
      arguments: _user,
    );
    if (result == true) {
      _loadVehicles();
    }
  }

  void _goToTopUp() async {
    final result = await Navigator.pushNamed(
      context,
      '/topup',
      arguments: _user,
    );
    if (result == true) {
      _loadWallet();
    }
  }

  void _goToFuelStations() {
    Navigator.pushNamed(context, '/fuel_stations', arguments: _user);
  }

  void _goToNotifications() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
        settings: RouteSettings(arguments: _user),
      ),
    );
    if (result == true) {
      await _loadUnreadCount();
    }
  }

  void _openFuelLogScreen() {
    if (_vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a vehicle first before logging fuel.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FuelLogScreen(
          user: _user!,
          vehicles: _vehicles,
          walletBalance: _wallet?.balance ?? 0.0,
        ),
      ),
    ).then((_) => _loadAll());
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _user;
    final hasUnread = _unreadCount > 0;

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
                      child: _buildTopBar(isDark, user, hasUnread),
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
                        KeyedSubtree(
                          key: _keyFuelLogAction,
                          child: _ActionCard(
                            icon: Icons.local_gas_station_rounded,
                            label: 'Fuel Log',
                            sublabel: 'Track refuels',
                            gradient: [
                              AppColors.emerald,
                              AppColors.emeraldDark,
                            ],
                            isDark: isDark,
                            onTap: _openFuelLogScreen,
                          ),
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
                              onTap: _openFuelLogScreen,
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
              'This is your home screen. See your greeting, NIC, and email at a glance.',
          icon: Icons.dashboard_rounded,
          gradient: [AppColors.emerald, AppColors.ocean],
          position: TooltipPosition.below,
        ),
        TourStep(
          targetKey: _keyWallet,
          title: 'Fuelix Wallet',
          body:
              'Your wallet balance is shown here. Tap to top up and manage your fuel credits.',
          icon: Icons.account_balance_wallet_rounded,
          gradient: [const Color(0xFF7C3AED), const Color(0xFF0A84FF)],
          position: TooltipPosition.below,
        ),
        TourStep(
          targetKey: _keyVehicles,
          title: 'My Vehicles',
          body:
              'Add and manage your vehicles here. Each vehicle gets a unique Fuel Pass QR code.',
          icon: Icons.directions_car_rounded,
          gradient: [AppColors.ocean, AppColors.emerald],
          position: TooltipPosition.below,
        ),
        TourStep(
          targetKey: _keyActions,
          title: 'Quick Actions',
          body:
              'Quick access to main features: Fuel Log, Analytics, Fuel Stations, and Top Up.',
          icon: Icons.grid_view_rounded,
          gradient: [AppColors.amber, AppColors.emerald],
          position: TooltipPosition.below,
        ),
        TourStep(
          targetKey: _keyFuelLogAction,
          title: 'Log Fuel',
          body:
              'Tap here to record your fuel refills. You\'ll need a vehicle added first.',
          icon: Icons.local_gas_station_rounded,
          gradient: [AppColors.emerald, AppColors.ocean],
          position: TooltipPosition.above,
        ),
        TourStep(
          targetKey: _keyNotifications,
          title: 'Notifications',
          body:
              'Tap the bell icon to see your alerts. The gold bell shows unread notifications.',
          icon: Icons.notifications_rounded,
          gradient: [AppColors.amber, AppColors.emerald],
          position: TooltipPosition.below,
        ),
      ],
      onComplete: () async {
        await TutorialService.markSeen(TutorialKey.homeTour);
        if (mounted) setState(() => _showTour = false);
      },
      child: screen,
    );
  }

  Widget _buildTopBar(bool isDark, UserModel? user, bool hasUnread) {
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
        // Animated Notifications Button
        KeyedSubtree(
          key: _keyNotifications,
          child: GestureDetector(
            onTap: _goToNotifications,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                if (_bellController != null) _bellController!,
                _counterController,
              ]),
              builder: (context, child) {
                return Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isDark
                        ? AppColors.darkSurfaceAlt
                        : AppColors.lightSurfaceAlt,
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Bell icon with animation (only the bell icon, not the container)
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
                            color: isDark
                                ? AppColors.darkTextSub
                                : AppColors.lightTextSub,
                          ),

                        // Counter badge
                        if (hasUnread)
                          Positioned(
                            right: -8,
                            top: -8,
                            child: ScaleTransition(
                              scale: _counterScale,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.error,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  _unreadCount > 9 ? '9+' : '$_unreadCount',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Log deleted'),
                  backgroundColor: AppColors.emerald,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['error']),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildEmptyActivity(bool isDark) {
    return GestureDetector(
      onTap: _openFuelLogScreen,
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
