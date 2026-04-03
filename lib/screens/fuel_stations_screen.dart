import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/fuel_station_model.dart';
import '../services/station_data_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/tutorial_overlay.dart';

// ─── Filter options ───────────────────────────────────────────────────────────
const _kBrands = ['All', 'CPC', 'Lanka IOC', 'Sinopec'];
const _kProvinces = [
  'All',
  'Western',
  'Central',
  'Southern',
  'Northern',
  'Eastern',
  'North Western',
  'North Central',
  'Uva',
  'Sabaragamuwa',
];
const _kFuelFilters = [
  'All',
  'Petrol 92',
  'Petrol 95',
  'Auto Diesel',
  'Super Diesel',
  'Kerosene',
];

// Default location (Colombo, Sri Lanka) if location services are disabled
const LatLng _defaultLocation = LatLng(6.9271, 79.8612);

// ═════════════════════════════════════════════════════════════════════════════
// FuelStationsScreen
// ═════════════════════════════════════════════════════════════════════════════
class FuelStationsScreen extends StatefulWidget {
  const FuelStationsScreen({super.key});

  @override
  State<FuelStationsScreen> createState() => _FuelStationsScreenState();
}

class _FuelStationsScreenState extends State<FuelStationsScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _user;
  final StationDataService _stationService = StationDataService();

  // Map state
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  bool _isLoadingStations = true;
  String? _locationError;
  MapController _mapController = MapController();
  double _currentZoom = 13.0;

  // Stations data
  List<FuelStation> _stationsWithinRadius = [];
  List<FuelStation> _allStations = [];
  bool _useDefaultLocation = false;

  // Filters
  final _searchCtrl = TextEditingController();
  String _selectedBrand = 'All';
  String _selectedProvince = 'All';
  String _selectedFuel = 'All';
  bool _partnerOnly = false;
  bool _openOnly = false;

  // View state
  bool _showFilters = false;
  bool _isListView = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // Tutorial keys
  final _keyToggleView = GlobalKey();
  final _keySearchBar = GlobalKey();
  final _keyFilterButton = GlobalKey();
  final _keyStationCard = GlobalKey();
  bool _showTour = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _searchCtrl.addListener(() => setState(() {}));
    _animCtrl.forward();
    _initializeData();
    _checkFuelStationsTour();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final u = ModalRoute.of(context)?.settings.arguments as UserModel?;
    if (u != null && _user == null) _user = u;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _animCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _checkFuelStationsTour() async {
    final seen = await TutorialService.isSeen(TutorialKey.fuelStationsTour);
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) setState(() => _showTour = true);
    }
  }

  Future<void> _initializeData() async {
    await _loadStations();
    await _getCurrentLocation();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoadingStations = true);
    _allStations = await _stationService.loadStations();
    setState(() => _isLoadingStations = false);
  }

  // ── Location handling ──────────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError =
              'Location services are disabled. Please enable location services to see stations near you.';
          _isLoadingLocation = false;
        });
        _updateStationsWithLocation(_defaultLocation);
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError =
                'Location permission denied. Please grant location permission to see stations near you.';
            _isLoadingLocation = false;
          });
          _updateStationsWithLocation(_defaultLocation);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError =
              'Location permission permanently denied. Please enable location permission in app settings.';
          _isLoadingLocation = false;
        });
        _updateStationsWithLocation(_defaultLocation);
        return;
      }

      // Get current position
      final position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Location request timed out');
            },
          );

      final currentLoc = LatLng(position.latitude, position.longitude);
      _updateStationsWithLocation(currentLoc);
    } on TimeoutException catch (_) {
      setState(() {
        _locationError = 'Location request timed out. Please try again.';
        _isLoadingLocation = false;
      });
      _updateStationsWithLocation(_defaultLocation);
    } catch (e) {
      print('Location error: $e');
      setState(() {
        _locationError =
            'Failed to get your location. Showing all stations instead.';
        _isLoadingLocation = false;
      });
      _updateStationsWithLocation(_defaultLocation);
    }
  }

  void _updateStationsWithLocation(LatLng location) {
    final stations = _stationService.getStationsWithinRadius(
      location.latitude,
      location.longitude,
    );

    if (mounted) {
      setState(() {
        _currentLocation = location;
        _stationsWithinRadius = stations;
        _isLoadingLocation = false;
        _useDefaultLocation = location == _defaultLocation;
      });
      _mapController.move(location, _currentZoom);
    }
  }

  void _centerOnUser() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, _currentZoom);
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _openDirections(FuelStation station) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${station.latitude},${station.longitude}';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        showAppSnackbar(context, message: 'Could not open maps', isError: true);
      }
    } catch (e) {
      showAppSnackbar(context, message: 'Error opening maps', isError: true);
    }
  }

  // ── Filter logic ──────────────────────────────────────────────────────────
  List<FuelStation> get _filtered {
    if (_stationsWithinRadius.isEmpty) return [];
    final q = _searchCtrl.text.trim().toLowerCase();
    return _stationsWithinRadius.where((s) {
      if (q.isNotEmpty &&
          !s.name.toLowerCase().contains(q) &&
          !s.address.toLowerCase().contains(q) &&
          !s.district.toLowerCase().contains(q))
        return false;
      if (_selectedBrand != 'All' && s.brand != _selectedBrand) return false;
      if (_selectedProvince != 'All' && s.province != _selectedProvince)
        return false;
      if (_selectedFuel != 'All' && !s.availableFuels.contains(_selectedFuel))
        return false;
      if (_partnerOnly && !s.isFuelixPartner) return false;
      if (_openOnly && !s.isOpen) return false;
      return true;
    }).toList()..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  }

  int get _activeFilterCount {
    int c = 0;
    if (_selectedBrand != 'All') c++;
    if (_selectedProvince != 'All') c++;
    if (_selectedFuel != 'All') c++;
    if (_partnerOnly) c++;
    if (_openOnly) c++;
    return c;
  }

  void _clearFilters() {
    setState(() {
      _selectedBrand = 'All';
      _selectedProvince = 'All';
      _selectedFuel = 'All';
      _partnerOnly = false;
      _openOnly = false;
    });
  }

  void _openDetail(FuelStation station) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StationDetailSheet(
        station: station,
        userLocation: _currentLocation,
        onDirections: () => _openDirections(station),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;

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
            child: Column(
              children: [
                _buildTopBar(isDark),
                _buildSearchBar(isDark),
                _buildViewToggle(isDark),
                _buildFilterChips(isDark),
                if (_showFilters) _buildFilterPanel(isDark),
                _buildStatsBar(isDark, filtered),
                Expanded(
                  child: _isLoadingStations
                      ? _buildLoadingState(isDark, 'Loading stations...')
                      : _isLoadingLocation
                      ? _buildLoadingState(isDark, 'Getting your location...')
                      : _stationsWithinRadius.isEmpty
                      ? _buildNoStationsNearbyState(isDark)
                      : _isListView
                      ? _buildListView(isDark, filtered)
                      : _buildMapView(isDark, filtered),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: !_isListView && _currentLocation != null
          ? FloatingActionButton(
              onPressed: _centerOnUser,
              backgroundColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              child: Icon(Icons.my_location_rounded, color: AppColors.emerald),
            )
          : null,
    );

    if (!_showTour) return screen;

    return SpotlightTour(
      steps: [
        TourStep(
          targetKey: _keyToggleView,
          title: 'List / Map View',
          body:
              'Switch between list view and interactive map view to find fuel stations.',
          icon: Icons.view_list_rounded,
          gradient: [AppColors.emerald, AppColors.ocean],
          position: TooltipPosition.below,
        ),
        TourStep(
          targetKey: _keySearchBar,
          title: 'Search Stations',
          body:
              'Search by station name, address, or district to quickly find what you need.',
          icon: Icons.search_rounded,
          gradient: [AppColors.ocean, AppColors.emerald],
          position: TooltipPosition.below,
        ),
        TourStep(
          targetKey: _keyFilterButton,
          title: 'Filters',
          body:
              'Filter by brand, province, fuel type, partner status, and open now.',
          icon: Icons.tune_rounded,
          gradient: [AppColors.amber, AppColors.emerald],
          position: TooltipPosition.below,
        ),
        TourStep(
          targetKey: _keyStationCard,
          title: 'Station Card',
          body:
              'Tap any station to see details, available fuels, amenities, and get directions.',
          icon: Icons.local_gas_station_rounded,
          gradient: [AppColors.emerald, AppColors.ocean],
          position: TooltipPosition.above,
        ),
      ],
      onComplete: () async {
        await TutorialService.markSeen(TutorialKey.fuelStationsTour);
        if (mounted) setState(() => _showTour = false);
      },
      child: screen,
    );
  }

  // ── Loading State ──────────────────────────────────────────────────────────
  Widget _buildLoadingState(bool isDark, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.emerald),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.inter(
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
        ],
      ),
    );
  }

  // ── No Stations Nearby State ───────────────────────────────────────────────
  Widget _buildNoStationsNearbyState(bool isDark) {
    final message = _useDefaultLocation
        ? 'Unable to get your location. Showing all stations across Sri Lanka.\n\nUse the map to explore stations.'
        : 'No fuel stations found within 30km of your location.\n\nTry expanding your search or check back later.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
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
                _useDefaultLocation
                    ? Icons.map_outlined
                    : Icons.local_gas_station_outlined,
                size: 38,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _useDefaultLocation
                  ? 'Using Default Location'
                  : 'No Stations Nearby',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
            const SizedBox(height: 20),
            if (!_useDefaultLocation)
              GradientButton(
                label: 'Retry',
                onPressed: _getCurrentLocation,
                height: 44,
                colors: [AppColors.emerald, AppColors.ocean],
              ),
            const SizedBox(height: 12),
            if (_useDefaultLocation)
              OutlinedAppButton(
                label: 'Switch to List View',
                icon: Icons.list_rounded,
                onPressed: () => setState(() => _isListView = true),
              ),
          ],
        ),
      ),
    );
  }

  // ── View Toggle ───────────────────────────────────────────────────────────
  Widget _buildViewToggle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: KeyedSubtree(
        key: _keyToggleView,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isDark
                ? AppColors.darkSurfaceAlt
                : AppColors.lightSurfaceAlt,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              _ToggleButton(
                label: 'List View',
                icon: Icons.list_rounded,
                isSelected: _isListView,
                isDark: isDark,
                onTap: () => setState(() => _isListView = true),
              ),
              _ToggleButton(
                label: 'Map View',
                icon: Icons.map_rounded,
                isSelected: !_isListView,
                isDark: isDark,
                onTap: () => setState(() => _isListView = false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Map View ──────────────────────────────────────────────────────────────
  Widget _buildMapView(bool isDark, List<FuelStation> stations) {
    if (stations.isEmpty) {
      return _buildNoStationsNearbyState(isDark);
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation ?? _defaultLocation,
        initialZoom: _currentZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.fuelix.app',
          tileProvider: NetworkTileProvider(),
        ),
        if (_currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                width: 40,
                height: 40,
                point: _currentLocation!,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emerald.withOpacity(0.2),
                    border: Border.all(color: AppColors.emerald, width: 3),
                  ),
                  child: const Icon(
                    Icons.my_location,
                    size: 20,
                    color: AppColors.emerald,
                  ),
                ),
              ),
            ],
          ),
        MarkerLayer(
          markers: stations.map((station) {
            return Marker(
              width: 50,
              height: 50,
              point: LatLng(station.latitude, station.longitude),
              child: GestureDetector(
                onTap: () => _openDetail(station),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: station.isFuelixPartner
                          ? [AppColors.emerald, AppColors.ocean]
                          : _brandGradient(station.brand),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.local_gas_station_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(bool isDark) {
    final stationCount = _stationsWithinRadius.length;
    final locationText = _useDefaultLocation
        ? 'Showing all stations'
        : '${stationCount} station${stationCount != 1 ? 's' : ''} within 30km';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: _iconBox(Icons.arrow_back_ios_new_rounded, isDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fuel Stations',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  locationText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
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
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: KeyedSubtree(
              key: _keySearchBar,
              child: Container(
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
                child: TextField(
                  controller: _searchCtrl,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search stations, districts...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: isDark
                          ? AppColors.darkTextSub
                          : AppColors.lightTextSub,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              FocusScope.of(context).unfocus();
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: isDark
                                  ? AppColors.darkTextSub
                                  : AppColors.lightTextSub,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          KeyedSubtree(
            key: _keyFilterButton,
            child: GestureDetector(
              onTap: () => setState(() => _showFilters = !_showFilters),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: _showFilters || _activeFilterCount > 0
                      ? const LinearGradient(
                          colors: [AppColors.emerald, AppColors.ocean],
                        )
                      : null,
                  color: _showFilters || _activeFilterCount > 0
                      ? null
                      : (isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface),
                  border: Border.all(
                    color: _showFilters || _activeFilterCount > 0
                        ? Colors.transparent
                        : (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: _showFilters || _activeFilterCount > 0
                          ? Colors.white
                          : (isDark
                                ? AppColors.darkTextSub
                                : AppColors.lightTextSub),
                    ),
                    if (_activeFilterCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.amber,
                          ),
                          child: Center(
                            child: Text(
                              '$_activeFilterCount',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chips (quick toggles) ──────────────────────────────────────────
  Widget _buildFilterChips(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 0, 0),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            _QuickChip(
              label: 'Fuelix Partners',
              icon: Icons.verified_rounded,
              active: _partnerOnly,
              color: AppColors.emerald,
              isDark: isDark,
              onTap: () => setState(() => _partnerOnly = !_partnerOnly),
            ),
            const SizedBox(width: 8),
            _QuickChip(
              label: 'Open Now',
              icon: Icons.access_time_rounded,
              active: _openOnly,
              color: AppColors.ocean,
              isDark: isDark,
              onTap: () => setState(() => _openOnly = !_openOnly),
            ),
            if (_activeFilterCount > 0) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _clearFilters,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.error.withOpacity(isDark ? 0.15 : 0.08),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Clear',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  // ── Expandable filter panel ───────────────────────────────────────────────
  Widget _buildFilterPanel(bool isDark) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'FILTERS',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emerald,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (_activeFilterCount > 0)
                  GestureDetector(
                    onTap: _clearFilters,
                    child: Text(
                      'Clear all',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _filterLabel('Brand', isDark),
            const SizedBox(height: 6),
            _buildHorizontalPills(
              items: _kBrands,
              selected: _selectedBrand,
              isDark: isDark,
              color: AppColors.ocean,
              onSelect: (v) => setState(() => _selectedBrand = v),
            ),
            const SizedBox(height: 14),
            _filterLabel('Province', isDark),
            const SizedBox(height: 6),
            _buildHorizontalPills(
              items: _kProvinces,
              selected: _selectedProvince,
              isDark: isDark,
              color: AppColors.emerald,
              onSelect: (v) => setState(() => _selectedProvince = v),
            ),
            const SizedBox(height: 14),
            _filterLabel('Fuel Type', isDark),
            const SizedBox(height: 6),
            _buildHorizontalPills(
              items: _kFuelFilters,
              selected: _selectedFuel,
              isDark: isDark,
              color: AppColors.amber,
              onSelect: (v) => setState(() => _selectedFuel = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterLabel(String text, bool isDark) => Text(
    text,
    style: GoogleFonts.spaceGrotesk(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      letterSpacing: 0.5,
    ),
  );

  Widget _buildHorizontalPills({
    required List<String> items,
    required String selected,
    required bool isDark,
    required Color color,
    required ValueChanged<String> onSelect,
  }) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final isSelected = items[i] == selected;
          return GestureDetector(
            onTap: () => onSelect(items[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isSelected
                    ? color.withOpacity(isDark ? 0.2 : 0.12)
                    : (isDark
                          ? AppColors.darkSurfaceAlt
                          : AppColors.lightSurfaceAlt),
                border: Border.all(
                  color: isSelected
                      ? color
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  items[i],
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? color
                        : (isDark
                              ? AppColors.darkTextSub
                              : AppColors.lightTextSub),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Stats bar ─────────────────────────────────────────────────────────────
  Widget _buildStatsBar(bool isDark, List<FuelStation> filtered) {
    final partners = filtered.where((s) => s.isFuelixPartner).length;
    final open = filtered.where((s) => s.isOpen).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${filtered.length} station${filtered.length != 1 ? 's' : ''} found',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
          ),
          _statBadge('$partners Partners', AppColors.emerald, isDark),
          const SizedBox(width: 6),
          _statBadge('$open Open', AppColors.ocean, isDark),
        ],
      ),
    );
  }

  Widget _statBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withOpacity(isDark ? 0.14 : 0.08),
      ),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ── List view ─────────────────────────────────────────────────────────────
  Widget _buildListView(bool isDark, List<FuelStation> stations) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: stations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        return KeyedSubtree(
          key: i == 0 ? _keyStationCard : null,
          child: _StationListCard(
            station: stations[i],
            isDark: isDark,
            onTap: () => _openDetail(stations[i]),
          ),
        );
      },
    );
  }

  Widget _iconBox(IconData icon, bool isDark) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
      border: Border.all(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
    ),
    child: Icon(
      icon,
      size: 16,
      color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Toggle Button
// ═════════════════════════════════════════════════════════════════════════════
class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppColors.emerald, AppColors.ocean],
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                            ? AppColors.darkTextSub
                            : AppColors.lightTextSub),
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
// Quick chip widget
// ═════════════════════════════════════════════════════════════════════════════
class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active
              ? color.withOpacity(isDark ? 0.18 : 0.10)
              : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          border: Border.all(
            color: active
                ? color
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: active
                  ? color
                  : (isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active
                    ? color
                    : (isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Brand helpers
// ═════════════════════════════════════════════════════════════════════════════
Color _brandColor(String brand) {
  switch (brand) {
    case 'CPC':
      return AppColors.ocean;
    case 'Lanka IOC':
      return AppColors.emerald;
    case 'Sinopec':
      return const Color(0xFFEF4444);
    default:
      return AppColors.amber;
  }
}

List<Color> _brandGradient(String brand) {
  switch (brand) {
    case 'CPC':
      return [AppColors.ocean, AppColors.oceanDark];
    case 'Lanka IOC':
      return [AppColors.emerald, AppColors.emeraldDark];
    case 'Sinopec':
      return [const Color(0xFFEF4444), const Color(0xFFDC2626)];
    default:
      return [AppColors.amber, AppColors.amberDark];
  }
}

Color _fuelGradeColor(String grade) {
  if (grade.contains('95')) return const Color(0xFF7C3AED);
  if (grade.contains('92')) return AppColors.ocean;
  if (grade.contains('Super')) return AppColors.amber;
  if (grade.contains('Auto')) return const Color(0xFFF97316);
  if (grade.contains('Kerosene')) return const Color(0xFF6B7280);
  return AppColors.emerald;
}

IconData _amenityIcon(String amenity) {
  switch (amenity) {
    case 'Air':
      return Icons.tire_repair_rounded;
    case 'Water':
      return Icons.water_drop_outlined;
    case 'Restroom':
      return Icons.wc_rounded;
    case 'Convenience Store':
      return Icons.store_rounded;
    default:
      return Icons.check_circle_outline;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Station List Card
// ═════════════════════════════════════════════════════════════════════════════
class _StationListCard extends StatelessWidget {
  final FuelStation station;
  final bool isDark;
  final VoidCallback onTap;

  const _StationListCard({
    required this.station,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _brandColor(station.brand);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border.all(
            color: station.isFuelixPartner
                ? AppColors.emerald.withOpacity(0.3)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: station.isFuelixPartner ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [accent, accent.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_gas_station_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                station.name,
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color:
                                    (station.isOpen
                                            ? AppColors.emerald
                                            : AppColors.error)
                                        .withOpacity(isDark ? 0.15 : 0.08),
                              ),
                              child: Text(
                                station.isOpen ? 'Open' : 'Closed',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: station.isOpen
                                      ? AppColors.emerald
                                      : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color: accent.withOpacity(isDark ? 0.15 : 0.08),
                              ),
                              child: Text(
                                station.brand,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (station.isFuelixPartner) ...[
                              const Icon(
                                Icons.verified_rounded,
                                size: 12,
                                color: AppColors.emerald,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Fuelix Partner',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.emerald,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 12,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                station.address,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.near_me_rounded,
                    size: 13,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${station.distanceKm.toStringAsFixed(1)} km',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextSub
                          : AppColors.lightTextSub,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    station.is24Hours
                        ? Icons.nightlight_round
                        : Icons.access_time_rounded,
                    size: 13,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    station.operatingHours,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSub
                          : AppColors.lightTextSub,
                    ),
                  ),
                  const Spacer(),
                  ...station.availableFuels
                      .take(2)
                      .map(
                        (f) => Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: _fuelGradeColor(
                              f,
                            ).withOpacity(isDark ? 0.14 : 0.08),
                          ),
                          child: Text(
                            f
                                .replaceAll('Auto ', '')
                                .replaceAll('Super ', 'S.')
                                .replaceAll('Petrol ', 'P'),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _fuelGradeColor(f),
                            ),
                          ),
                        ),
                      ),
                  if (station.availableFuels.length > 2)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: (isDark
                            ? AppColors.darkSurfaceAlt
                            : AppColors.lightSurfaceAlt),
                      ),
                      child: Text(
                        '+${station.availableFuels.length - 2}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextSub
                              : AppColors.lightTextSub,
                        ),
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
}

// ═════════════════════════════════════════════════════════════════════════════
// Station Detail Bottom Sheet
// ═════════════════════════════════════════════════════════════════════════════
class _StationDetailSheet extends StatelessWidget {
  final FuelStation station;
  final LatLng? userLocation;
  final VoidCallback onDirections;

  const _StationDetailSheet({
    required this.station,
    this.userLocation,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _brandColor(station.brand);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [
                      accent,
                      accent.withOpacity(0.75),
                      AppColors.ocean.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.35),
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
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: const Icon(
                            Icons.local_gas_station_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                station.brand,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.75),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                station.name,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white.withOpacity(0.2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: station.isOpen
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    station.isOpen ? 'Open' : 'Closed',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (station.isFuelixPartner) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.white.withOpacity(0.15),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Fuelix Partner',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(height: 1, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            station.address,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withOpacity(0.15),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.near_me_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${station.distanceKm.toStringAsFixed(1)} km',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _DetailSection(
              title: 'OPERATING HOURS',
              accentColor: AppColors.amber,
              isDark: isDark,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.amber.withOpacity(
                          isDark ? 0.12 : 0.07,
                        ),
                      ),
                      child: Icon(
                        station.is24Hours
                            ? Icons.nightlight_round
                            : Icons.access_time_rounded,
                        size: 18,
                        color: AppColors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.operatingHours,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                        ),
                        Text(
                          station.is24Hours
                              ? 'Open every day, all hours'
                              : 'Monday – Sunday',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color:
                            (station.isOpen
                                    ? AppColors.emerald
                                    : AppColors.error)
                                .withOpacity(isDark ? 0.15 : 0.08),
                        border: Border.all(
                          color:
                              (station.isOpen
                                      ? AppColors.emerald
                                      : AppColors.error)
                                  .withOpacity(0.35),
                        ),
                      ),
                      child: Text(
                        station.isOpen ? 'Open Now' : 'Closed',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: station.isOpen
                              ? AppColors.emerald
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _DetailSection(
              title: 'AVAILABLE FUELS',
              accentColor: AppColors.emerald,
              isDark: isDark,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: station.availableFuels.map((f) {
                    final fc = _fuelGradeColor(f);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: fc.withOpacity(isDark ? 0.14 : 0.08),
                        border: Border.all(color: fc.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: fc,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            f,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: fc,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _DetailSection(
              title: 'AMENITIES',
              accentColor: AppColors.ocean,
              isDark: isDark,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Row(
                  children: station.amenities.map((a) {
                    return Container(
                      margin: const EdgeInsets.only(right: 10),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: AppColors.ocean.withOpacity(
                                isDark ? 0.12 : 0.07,
                              ),
                            ),
                            child: Icon(
                              _amenityIcon(a),
                              size: 20,
                              color: AppColors.ocean,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            a.replaceAll(' ', '\n'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: isDark
                                  ? AppColors.darkTextSub
                                  : AppColors.lightTextSub,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _DetailSection(
              title: 'LOCATION',
              accentColor: const Color(0xFF7C3AED),
              isDark: isDark,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      children: [
                        _locationRow(
                          Icons.place_outlined,
                          'Address',
                          station.address,
                          isDark,
                        ),
                        const SizedBox(height: 10),
                        _locationRow(
                          Icons.location_city_outlined,
                          'District',
                          station.district,
                          isDark,
                        ),
                        const SizedBox(height: 10),
                        _locationRow(
                          Icons.map_outlined,
                          'Province',
                          station.province,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          options: MapOptions(
                            center: LatLng(station.latitude, station.longitude),
                            zoom: 15,
                            interactiveFlags:
                                InteractiveFlag.pinchZoom |
                                InteractiveFlag.drag,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.fuelix.app',
                              tileProvider: NetworkTileProvider(),
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 40,
                                  height: 40,
                                  point: LatLng(
                                    station.latitude,
                                    station.longitude,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          accent,
                                          accent.withOpacity(0.7),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accent.withOpacity(0.3),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.local_gas_station_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GradientButton(
                label: 'Get Directions',
                onPressed: onDirections,
                colors: [const Color(0xFF7C3AED), AppColors.ocean],
              ),
            ),
            const SizedBox(height: 12),
            if (station.isFuelixPartner) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppColors.emerald.withOpacity(isDark ? 0.10 : 0.06),
                    border: Border.all(
                      color: AppColors.emerald.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppColors.emerald,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This is an authorised Fuelix partner station. You can use your vehicle\'s Fuel Pass QR code to refuel here.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.emerald,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _locationRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: const Color(0xFF7C3AED).withOpacity(isDark ? 0.12 : 0.07),
          ),
          child: Icon(icon, size: 15, color: const Color(0xFF7C3AED)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Detail section wrapper ───────────────────────────────────────────────────
class _DetailSection extends StatelessWidget {
  final String title;
  final Color accentColor;
  final bool isDark;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.accentColor,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 13,
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
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}
