import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../widgets/custom_button.dart';

// ─── Station Model ────────────────────────────────────────────────────────────
class FuelStation {
  final int id;
  final String name;
  final String brand; // CPC, IOC, Lanka IOC, Sinopec, Ceylon Petroleum
  final String address;
  final String district;
  final String province;
  final double latitude;
  final double longitude;
  final List<String> availableFuels; // Petrol 92, Petrol 95, Auto Diesel, etc.
  final bool isFuelixPartner;
  final bool is24Hours;
  final String operatingHours; // e.g. "6:00 AM – 10:00 PM"
  final List<String> amenities; // Air, Water, Restroom, Convenience Store
  final double distanceKm; // mock distance
  final bool isOpen;

  const FuelStation({
    required this.id,
    required this.name,
    required this.brand,
    required this.address,
    required this.district,
    required this.province,
    required this.latitude,
    required this.longitude,
    required this.availableFuels,
    required this.isFuelixPartner,
    required this.is24Hours,
    required this.operatingHours,
    required this.amenities,
    required this.distanceKm,
    required this.isOpen,
  });
}

// ─── Mock Station Data ────────────────────────────────────────────────────────
final List<FuelStation> _kAllStations = [
  FuelStation(
    id: 1,
    name: 'CPC Colombo 3',
    brand: 'CPC',
    address: 'No. 45, Galle Road, Colombo 03',
    district: 'Colombo',
    province: 'Western',
    latitude: 6.8947,
    longitude: 79.8534,
    availableFuels: [
      'Petrol 92',
      'Petrol 95',
      'Auto Diesel',
      'Super Diesel',
      'Kerosene',
    ],
    isFuelixPartner: true,
    is24Hours: true,
    operatingHours: '24 Hours',
    amenities: ['Air', 'Water', 'Restroom', 'Convenience Store'],
    distanceKm: 1.2,
    isOpen: true,
  ),
  FuelStation(
    id: 2,
    name: 'Lanka IOC Nugegoda',
    brand: 'Lanka IOC',
    address: 'High Level Road, Nugegoda',
    district: 'Colombo',
    province: 'Western',
    latitude: 6.8713,
    longitude: 79.8900,
    availableFuels: ['Petrol 92', 'Petrol 95', 'Auto Diesel', 'Super Diesel'],
    isFuelixPartner: true,
    is24Hours: false,
    operatingHours: '6:00 AM – 10:00 PM',
    amenities: ['Air', 'Water', 'Restroom'],
    distanceKm: 3.4,
    isOpen: true,
  ),
  FuelStation(
    id: 3,
    name: 'Sinopec Dehiwala',
    brand: 'Sinopec',
    address: 'Galle Road, Dehiwala',
    district: 'Colombo',
    province: 'Western',
    latitude: 6.8500,
    longitude: 79.8650,
    availableFuels: ['Petrol 92', 'Petrol 95', 'Auto Diesel'],
    isFuelixPartner: false,
    is24Hours: false,
    operatingHours: '7:00 AM – 9:00 PM',
    amenities: ['Air', 'Water'],
    distanceKm: 4.1,
    isOpen: true,
  ),
  FuelStation(
    id: 4,
    name: 'CPC Kandy City',
    brand: 'CPC',
    address: 'Dalada Veediya, Kandy',
    district: 'Kandy',
    province: 'Central',
    latitude: 7.2906,
    longitude: 80.6337,
    availableFuels: [
      'Petrol 92',
      'Petrol 95',
      'Auto Diesel',
      'Super Diesel',
      'Kerosene',
    ],
    isFuelixPartner: true,
    is24Hours: true,
    operatingHours: '24 Hours',
    amenities: ['Air', 'Water', 'Restroom', 'Convenience Store'],
    distanceKm: 115.2,
    isOpen: true,
  ),
  FuelStation(
    id: 5,
    name: 'Lanka IOC Galle',
    brand: 'Lanka IOC',
    address: 'Matara Road, Galle',
    district: 'Galle',
    province: 'Southern',
    latitude: 6.0535,
    longitude: 80.2210,
    availableFuels: ['Petrol 92', 'Petrol 95', 'Auto Diesel', 'Super Diesel'],
    isFuelixPartner: true,
    is24Hours: false,
    operatingHours: '6:00 AM – 11:00 PM',
    amenities: ['Air', 'Water', 'Restroom'],
    distanceKm: 120.7,
    isOpen: true,
  ),
  FuelStation(
    id: 6,
    name: 'CPC Gampaha',
    brand: 'CPC',
    address: 'Colombo Road, Gampaha',
    district: 'Gampaha',
    province: 'Western',
    latitude: 7.0840,
    longitude: 79.9990,
    availableFuels: ['Petrol 92', 'Auto Diesel', 'Kerosene'],
    isFuelixPartner: false,
    is24Hours: false,
    operatingHours: '6:00 AM – 9:00 PM',
    amenities: ['Air', 'Water'],
    distanceKm: 28.5,
    isOpen: false,
  ),
  FuelStation(
    id: 7,
    name: 'Sinopec Kelaniya',
    brand: 'Sinopec',
    address: 'Kandy Road, Kelaniya',
    district: 'Gampaha',
    province: 'Western',
    latitude: 7.0028,
    longitude: 79.9198,
    availableFuels: ['Petrol 92', 'Petrol 95', 'Auto Diesel', 'Super Diesel'],
    isFuelixPartner: true,
    is24Hours: false,
    operatingHours: '5:30 AM – 10:30 PM',
    amenities: ['Air', 'Water', 'Restroom'],
    distanceKm: 14.8,
    isOpen: true,
  ),
  FuelStation(
    id: 8,
    name: 'Lanka IOC Negombo',
    brand: 'Lanka IOC',
    address: 'Colombo Road, Negombo',
    district: 'Gampaha',
    province: 'Western',
    latitude: 7.2081,
    longitude: 79.8358,
    availableFuels: ['Petrol 92', 'Petrol 95', 'Auto Diesel'],
    isFuelixPartner: false,
    is24Hours: true,
    operatingHours: '24 Hours',
    amenities: ['Air', 'Water', 'Convenience Store'],
    distanceKm: 35.6,
    isOpen: true,
  ),
  FuelStation(
    id: 9,
    name: 'CPC Matara',
    brand: 'CPC',
    address: 'Main Street, Matara',
    district: 'Matara',
    province: 'Southern',
    latitude: 5.9549,
    longitude: 80.5550,
    availableFuels: [
      'Petrol 92',
      'Petrol 95',
      'Auto Diesel',
      'Super Diesel',
      'Kerosene',
    ],
    isFuelixPartner: true,
    is24Hours: false,
    operatingHours: '6:00 AM – 10:00 PM',
    amenities: ['Air', 'Water', 'Restroom'],
    distanceKm: 158.3,
    isOpen: true,
  ),
  FuelStation(
    id: 10,
    name: 'CPC Jaffna',
    brand: 'CPC',
    address: 'Hospital Road, Jaffna',
    district: 'Jaffna',
    province: 'Northern',
    latitude: 9.6615,
    longitude: 80.0255,
    availableFuels: ['Petrol 92', 'Auto Diesel', 'Kerosene'],
    isFuelixPartner: true,
    is24Hours: false,
    operatingHours: '7:00 AM – 8:00 PM',
    amenities: ['Air', 'Water'],
    distanceKm: 398.1,
    isOpen: true,
  ),
  FuelStation(
    id: 11,
    name: 'Sinopec Ratnapura',
    brand: 'Sinopec',
    address: 'Main Street, Ratnapura',
    district: 'Ratnapura',
    province: 'Sabaragamuwa',
    latitude: 6.6804,
    longitude: 80.3994,
    availableFuels: ['Petrol 92', 'Petrol 95', 'Auto Diesel'],
    isFuelixPartner: true,
    is24Hours: false,
    operatingHours: '6:30 AM – 9:30 PM',
    amenities: ['Air', 'Water', 'Restroom'],
    distanceKm: 101.4,
    isOpen: true,
  ),
  FuelStation(
    id: 12,
    name: 'Lanka IOC Kurunegala',
    brand: 'Lanka IOC',
    address: 'Colombo Road, Kurunegala',
    district: 'Kurunegala',
    province: 'North Western',
    latitude: 7.4818,
    longitude: 80.3609,
    availableFuels: ['Petrol 92', 'Petrol 95', 'Auto Diesel', 'Super Diesel'],
    isFuelixPartner: false,
    is24Hours: false,
    operatingHours: '6:00 AM – 10:00 PM',
    amenities: ['Air', 'Water'],
    distanceKm: 93.7,
    isOpen: false,
  ),
];

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

  // ── Filters ───────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _selectedBrand = 'All';
  String _selectedProvince = 'All';
  String _selectedFuel = 'All';
  bool _partnerOnly = false;
  bool _openOnly = false;

  // ── View ──────────────────────────────────────────────────────────────────
  bool _showFilters = false;
  bool _isListView = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

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
    super.dispose();
  }

  // ── Filter logic ──────────────────────────────────────────────────────────
  List<FuelStation> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _kAllStations.where((s) {
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;

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
            child: Column(
              children: [
                // ── Top bar ────────────────────────────────────────────
                _buildTopBar(isDark),
                // ── Search bar ─────────────────────────────────────────
                _buildSearchBar(isDark),
                // ── Filter chips row ───────────────────────────────────
                _buildFilterChips(isDark),
                // ── Filter panel (expandable) ──────────────────────────
                if (_showFilters) _buildFilterPanel(isDark),
                // ── Stats bar ──────────────────────────────────────────
                _buildStatsBar(isDark, filtered),
                // ── List / Grid ────────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmpty(isDark)
                      : _isListView
                      ? _buildListView(isDark, filtered)
                      : _buildGridView(isDark, filtered),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(bool isDark) {
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
                  '${_kAllStations.length} stations across Sri Lanka',
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
          // View toggle
          GestureDetector(
            onTap: () => setState(() => _isListView = !_isListView),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: isDark
                    ? AppColors.darkSurfaceAlt
                    : AppColors.lightSurfaceAlt,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Icon(
                _isListView ? Icons.grid_view_rounded : Icons.list_rounded,
                size: 18,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
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
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
          const SizedBox(width: 10),
          // Filter toggle button
          GestureDetector(
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
                    : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                border: Border.all(
                  color: _showFilters || _activeFilterCount > 0
                      ? Colors.transparent
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
            const SizedBox(width: 8),
            _QuickChip(
              label: '24 Hours',
              icon: Icons.nightlight_round,
              active: false,
              color: const Color(0xFF7C3AED),
              isDark: isDark,
              onTap: () {
                setState(() {
                  _openOnly = true;
                  // filter applied via open now
                });
              },
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
            // Brand
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
            // Province
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
            // Fuel type
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
      itemBuilder: (_, i) => _StationListCard(
        station: stations[i],
        isDark: isDark,
        onTap: () => _openDetail(stations[i]),
      ),
    );
  }

  // ── Grid view ─────────────────────────────────────────────────────────────
  Widget _buildGridView(bool isDark, List<FuelStation> stations) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: stations.length,
      itemBuilder: (_, i) => _StationGridCard(
        station: stations[i],
        isDark: isDark,
        onTap: () => _openDetail(stations[i]),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmpty(bool isDark) {
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
                Icons.local_gas_station_outlined,
                size: 38,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No stations found',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search or filters.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                _clearFilters();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [AppColors.emerald, AppColors.ocean],
                  ),
                ),
                child: Text(
                  'Clear Filters',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Detail sheet ──────────────────────────────────────────────────────────
  void _openDetail(FuelStation station) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StationDetailSheet(station: station),
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
// Brand color/icon helpers
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
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand icon
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
                            // Open/closed badge
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
            // ── Divider ───────────────────────────────────────────────
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            // ── Footer ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  // Distance
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
                  // Hours
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
                  // Fuel grade chips (first 2)
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
// Station Grid Card
// ═════════════════════════════════════════════════════════════════════════════
class _StationGridCard extends StatelessWidget {
  final FuelStation station;
  final bool isDark;
  final VoidCallback onTap;

  const _StationGridCard({
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border.all(
            color: station.isFuelixPartner
                ? AppColors.emerald.withOpacity(0.3)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: station.isFuelixPartner ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [accent, accent.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.local_gas_station_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color:
                        (station.isOpen ? AppColors.emerald : AppColors.error)
                            .withOpacity(isDark ? 0.15 : 0.08),
                  ),
                  child: Text(
                    station.isOpen ? 'Open' : 'Closed',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: station.isOpen
                          ? AppColors.emerald
                          : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              station.name,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: accent.withOpacity(isDark ? 0.15 : 0.08),
              ),
              child: Text(
                station.brand,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
            const Spacer(),
            if (station.isFuelixPartner)
              Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    size: 11,
                    color: AppColors.emerald,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Partner',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.emerald,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.near_me_rounded,
                  size: 11,
                  color: AppColors.ocean,
                ),
                const SizedBox(width: 3),
                Text(
                  '${station.distanceKm.toStringAsFixed(1)} km',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ocean,
                  ),
                ),
                const Spacer(),
                Text(
                  station.district,
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
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Station Detail Bottom Sheet
// ═════════════════════════════════════════════════════════════════════════════
class _StationDetailSheet extends StatelessWidget {
  final FuelStation station;

  const _StationDetailSheet({required this.station});

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
            // Handle
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

            // ── Hero card ────────────────────────────────────────────
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
                        // Open/Closed + Fuelix
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
                    // Address & distance
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

            // ── Operating hours ───────────────────────────────────────
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

            // ── Available fuels ───────────────────────────────────────
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

            // ── Amenities ─────────────────────────────────────────────
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

            // ── Location info ────────────────────────────────────────
            _DetailSection(
              title: 'LOCATION',
              accentColor: const Color(0xFF7C3AED),
              isDark: isDark,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
            ),

            // ── Fuelix partner notice ────────────────────────────────
            if (station.isFuelixPartner) ...[
              const SizedBox(height: 14),
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
