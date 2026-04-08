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
import '../screens/fuel_log_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/qr_scanner_screen.dart';
import 'home/widgets/top_bar.dart';
import 'home/widgets/welcome_card.dart';
import 'home/widgets/stats_row.dart';
import 'home/widgets/wallet_preview.dart';
import 'home/widgets/my_vehicles.dart';
import 'home/widgets/quick_actions.dart';
import 'home/widgets/recent_fuel_logs.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
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
  int _unreadCount = 0;
  final ApiService _apiService = ApiService();
  final NotificationLocalService _localService = NotificationLocalService();

  bool _isRefreshing = false;

  // Tutorial keys
  final _keyWelcome = GlobalKey();
  final _keyVehicles = GlobalKey();
  final _keyWallet = GlobalKey();
  final _keyActions = GlobalKey();
  final _keyFuelLogAction = GlobalKey();
  final _keyNotifications = GlobalKey();
  final _keyRefreshButton = GlobalKey();
  final _keyQrScan = GlobalKey();
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
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is UserModel && _user?.id != args.id) {
      _user = args;
      print('HomeScreen - User role received: ${_user?.role}');
      print('HomeScreen - Is staff: ${_user?.isStaff}');
      _loadAll();
      _checkHomeTour();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkHomeTour() async {
    final seen = await TutorialService.isSeen(TutorialKey.homeTour);
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _showTour = true);
    }
  }

  Future<void> _loadAll() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    await Future.wait([
      _loadVehicles(),
      _loadWallet(),
      _loadFuelData(),
      _loadUnreadCount(),
    ]);

    setState(() => _isRefreshing = false);
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
        balance: (data['balance'] as num).toDouble(),
        updatedAt: data['updatedAt'] != null
            ? DateTime.tryParse(data['updatedAt'])
            : null,
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
              litres: (json['litres'] as num).toDouble(),
              fuelType: json['fuelType'],
              fuelGrade: json['fuelGrade'],
              pricePerLitre: (json['pricePerLitre'] as num).toDouble(),
              totalCost: (json['totalCost'] as num).toDouble(),
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
            if (!isRead) unread++;
          }
        }
        setState(() => _unreadCount = unread);
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
      await _loadAll();
    }
  }

  void _goToTopUp() async {
    final result = await Navigator.pushNamed(
      context,
      '/topup',
      arguments: _user,
    );
    if (result == true) {
      await _loadAll();
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
    if (result == true) await _loadUnreadCount();
  }

  void _openQrScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QrScannerScreen(user: _user)),
    ).then((result) {
      if (result == true) {
        _loadAll();
      }
    });
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
              child: RefreshIndicator(
                onRefresh: _loadAll,
                color: AppColors.emerald,
                displacement: 40,
                edgeOffset: 20,
                strokeWidth: 2.5,
                triggerMode: RefreshIndicatorTriggerMode.onEdge,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: TopBar(
                          user: _user,
                          unreadCount: _unreadCount,
                          isDark: isDark,
                          onProfileTap: () => Navigator.pushNamed(
                            context,
                            '/profile',
                            arguments: _user,
                          ),
                          onNotificationsTap: _goToNotifications,
                          onQrScanTap: _openQrScanner,
                          notificationsKey: _keyNotifications,
                          qrScanKey: _keyQrScan,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                        child: KeyedSubtree(
                          key: _keyWelcome,
                          child: WelcomeCard(user: _user, isDark: isDark),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: StatsRow(stats: _stats, isDark: isDark),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                        child: KeyedSubtree(
                          key: _keyWallet,
                          child: WalletPreview(
                            wallet: _wallet,
                            isDark: isDark,
                            onTap: _goToTopUp,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                        child: KeyedSubtree(
                          key: _keyVehicles,
                          child: MyVehicles(
                            vehicles: _vehicles,
                            isDark: isDark,
                            onManageTap: _goToVehicles,
                          ),
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
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: QuickActions(
                          isDark: isDark,
                          onFuelLog: _openFuelLogScreen,
                          onAnalytics: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Analytics coming soon!'),
                              ),
                            );
                          },
                          onFuelStations: _goToFuelStations,
                          onTopUp: _goToTopUp,
                          fuelLogKey: _keyFuelLogAction,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
                        child: RecentFuelLogs(
                          recentLogs: _recentLogs,
                          vehicles: _vehicles,
                          isDark: isDark,
                          onAddLog: _openFuelLogScreen,
                          onRefresh: _loadAll,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
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
        TourStep(
          targetKey: _keyQrScan,
          title: 'QR Scanner',
          body:
              'Tap here to scan QR codes at fuel stations for quick fuel logging and payments.',
          icon: Icons.qr_code_scanner_rounded,
          gradient: [AppColors.emerald, AppColors.ocean],
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
}
