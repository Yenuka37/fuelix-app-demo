import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/topup_model.dart';
import '../models/fuel_log_model.dart';
import '../services/api_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/tutorial_overlay.dart';

// Fuel grade model from backend
class FuelGrade {
  final int id;
  final String name;
  final double pricePerLitre;
  final String fuelType;

  const FuelGrade({
    required this.id,
    required this.name,
    required this.pricePerLitre,
    required this.fuelType,
  });
}

class FuelLogScreen extends StatefulWidget {
  final UserModel user;
  final List<VehicleModel> vehicles;
  final double walletBalance;

  const FuelLogScreen({
    super.key,
    required this.user,
    required this.vehicles,
    required this.walletBalance,
  });

  @override
  State<FuelLogScreen> createState() => _FuelLogScreenState();
}

class _FuelLogScreenState extends State<FuelLogScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  late VehicleModel _selectedVehicle;
  FuelGrade? _selectedGrade;
  List<FuelGrade> _availableGrades = [];

  final _litresCtrl = TextEditingController();
  final _stationCtrl = TextEditingController();

  bool _isSaving = false;
  double _quotaRemaining = 0;
  double _walletBalance = 0;
  bool _limitsLoaded = false;
  List<VehicleModel> _vehicles = [];
  List<FuelGrade> _allFuelGrades = [];

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // Tutorial keys
  final _keyVehicleSelector = GlobalKey();
  final _keyGradeSelector = GlobalKey();
  final _keyLitresField = GlobalKey();
  final _keySaveButton = GlobalKey();
  bool _showTour = false;

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
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    _vehicles = List.from(widget.vehicles);
    _walletBalance = widget.walletBalance;

    if (_vehicles.isNotEmpty) {
      _selectedVehicle = _vehicles.first;
      _litresCtrl.addListener(() => setState(() {}));
      _loadFuelPrices();
    }

    _animCtrl.forward();
    _checkFuelLogTour();
  }

  @override
  void dispose() {
    _litresCtrl.dispose();
    _stationCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkFuelLogTour() async {
    final seen = await TutorialService.isSeen(TutorialKey.fuelLogTour);
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _showTour = true);
    }
  }

  // Load fuel prices from backend
  Future<void> _loadFuelPrices() async {
    try {
      final result = await _apiService.getFuelPrices();
      if (result['success'] && mounted) {
        List<dynamic> pricesJson = result['data'];
        _allFuelGrades = pricesJson
            .map(
              (json) => FuelGrade(
                id: json['id'],
                name: json['fuelGrade'],
                pricePerLitre: (json['pricePerLitre'] as num).toDouble(),
                fuelType: json['fuelType'],
              ),
            )
            .toList();

        await _refreshGradesAndLimits();
      } else {
        print('Failed to load fuel prices: ${result['error']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to load fuel prices. Please check your connection.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading fuel prices: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load fuel prices. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _refreshGradesAndLimits() async {
    if (_vehicles.isEmpty) {
      setState(() => _limitsLoaded = true);
      return;
    }

    setState(() => _limitsLoaded = false);

    // Filter grades by vehicle fuel type
    final grades = _allFuelGrades.where((g) {
      if (_selectedVehicle.fuelType.toLowerCase() == 'hybrid') {
        return g.fuelType.toLowerCase() == 'petrol' ||
            g.fuelType.toLowerCase() == 'diesel';
      }
      return g.fuelType.toLowerCase() ==
          _selectedVehicle.fuelType.toLowerCase();
    }).toList();

    // Get fresh quota from API
    final quotaResult = await _apiService.getCurrentQuota(
      _selectedVehicle.id!,
      _selectedVehicle.type,
    );

    double remaining = 0;
    if (quotaResult['success']) {
      remaining = quotaResult['data']['remainingLitres']?.toDouble() ?? 0;
    }

    // Get fresh wallet balance
    final walletResult = await _apiService.getWallet(widget.user.id!);
    double freshBalance = widget.walletBalance;
    if (walletResult['success']) {
      freshBalance = (walletResult['data']['balance'] as num).toDouble();
    }

    if (!mounted) return;
    setState(() {
      _availableGrades = grades;
      _selectedGrade = grades.isNotEmpty ? grades.first : null;
      _quotaRemaining = remaining;
      _walletBalance = freshBalance;
      _limitsLoaded = true;
      _litresCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGrade == null) return;

    setState(() => _isSaving = true);

    final litres = double.parse(_litresCtrl.text.trim());

    final logData = {
      'userId': widget.user.id!,
      'vehicleId': _selectedVehicle.id!,
      'litres': litres,
      'fuelType': _selectedVehicle.fuelType,
      'fuelGrade': _selectedGrade!.name,
      'vehicleType': _selectedVehicle.type,
      'stationName': _stationCtrl.text.trim(),
    };

    final result = await _apiService.addFuelLog(logData);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success']) {
      // Refresh data after successful fuel log
      await _loadFuelPrices();
      await _refreshVehicles();

      if (mounted) {
        Navigator.pop(context, true);
        showAppSnackbar(
          context,
          message: 'Fuel log saved successfully!',
          isSuccess: true,
        );
      }
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

  // Refresh vehicles from API
  Future<void> _refreshVehicles() async {
    try {
      final result = await _apiService.getVehicles(widget.user.id!);
      if (result['success'] && mounted) {
        List<dynamic> vehiclesJson = result['data'];
        List<VehicleModel> freshVehicles = vehiclesJson
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

        setState(() {
          _vehicles = freshVehicles;
        });

        if (_vehicles.isNotEmpty && !_vehicles.contains(_selectedVehicle)) {
          setState(() {
            _selectedVehicle = _vehicles.first;
          });
          await _refreshGradesAndLimits();
        } else if (_vehicles.isEmpty) {
          setState(() {
            _limitsLoaded = true;
          });
        }
      }
    } catch (e) {
      print('Error refreshing vehicles: $e');
    }
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
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
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
                        child: Text(
                          'Log Fuel',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      // Refresh button
                      GestureDetector(
                        onTap: _refreshVehicles,
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
                            Icons.refresh_rounded,
                            size: 18,
                            color: isDark
                                ? AppColors.darkTextSub
                                : AppColors.lightTextSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Divider(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  height: 1,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    child: _vehicles.isEmpty
                        ? _buildEmptyVehiclesState(isDark)
                        : Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Vehicle selector
                                _sectionLabel('Vehicle', isDark),
                                const SizedBox(height: 8),
                                KeyedSubtree(
                                  key: _keyVehicleSelector,
                                  child: _dropdown<VehicleModel>(
                                    isDark: isDark,
                                    value: _selectedVehicle,
                                    items: _vehicles,
                                    itemLabel: (v) =>
                                        '${v.shortDisplay} · ${v.registrationNo}',
                                    onChanged: (v) async {
                                      if (v == null) return;
                                      setState(() => _selectedVehicle = v);
                                      await _refreshGradesAndLimits();
                                    },
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Quota + wallet info bar
                                if (_limitsLoaded)
                                  _buildLimitsBar(isDark)
                                else
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.emerald,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 20),

                                // Fuel grade selector
                                if (_availableGrades.isEmpty) ...[
                                  _buildUnsupportedFuelNote(isDark),
                                ] else ...[
                                  _sectionLabel('Fuel Grade', isDark),
                                  const SizedBox(height: 10),
                                  KeyedSubtree(
                                    key: _keyGradeSelector,
                                    child: _buildGradeSelector(isDark),
                                  ),
                                  const SizedBox(height: 20),

                                  // Litres field
                                  _sectionLabel('Litres Filled', isDark),
                                  const SizedBox(height: 8),
                                  KeyedSubtree(
                                    key: _keyLitresField,
                                    child: _buildLitresField(isDark),
                                  ),
                                  const SizedBox(height: 20),

                                  // Station name
                                  AppTextField(
                                    label: 'Station Name (optional)',
                                    hint: 'e.g. CPC Colombo 7',
                                    controller: _stationCtrl,
                                    prefixIcon: Icons.place_outlined,
                                  ),
                                  const SizedBox(height: 20),

                                  // Cost preview
                                  if (_totalCost > 0) _buildCostPreview(isDark),
                                  const SizedBox(height: 8),

                                  // Save button
                                  KeyedSubtree(
                                    key: _keySaveButton,
                                    child: GradientButton(
                                      label: 'Save Fuel Log',
                                      onPressed:
                                          (_limitsLoaded && _maxLitres > 0)
                                          ? _save
                                          : null,
                                      isLoading: _isSaving,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!_showTour) return screen;

    return SpotlightTour(
      steps: [
        TourStep(
          targetKey: _keyVehicleSelector,
          title: 'Select Vehicle',
          body:
              'Choose the vehicle you refueled. Each vehicle has its own quota.',
          icon: Icons.directions_car_rounded,
          gradient: [AppColors.ocean, AppColors.emerald],
          position: TooltipPosition.below,
        ),
        TourStep(
          targetKey: _keyGradeSelector,
          title: 'Choose Fuel Grade',
          body: 'Select the correct fuel grade. Prices are updated by admin.',
          icon: Icons.local_gas_station_rounded,
          gradient: [AppColors.emerald, AppColors.ocean],
          position: TooltipPosition.below,
        ),
        TourStep(
          targetKey: _keyLitresField,
          title: 'Enter Litres',
          body:
              'Input the exact litres filled. Check quota and wallet limits above.',
          icon: Icons.opacity_rounded,
          gradient: [AppColors.amber, AppColors.emerald],
          position: TooltipPosition.below,
        ),
        TourStep(
          targetKey: _keySaveButton,
          title: 'Save Fuel Log',
          body: 'Tap to record your refuel. Quota and wallet will be updated.',
          icon: Icons.save_rounded,
          gradient: [AppColors.emerald, AppColors.ocean],
          position: TooltipPosition.above,
        ),
      ],
      onComplete: () async {
        await TutorialService.markSeen(TutorialKey.fuelLogTour);
        if (mounted) setState(() => _showTour = false);
      },
      child: screen,
    );
  }

  Widget _buildEmptyVehiclesState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
              Icons.directions_car_outlined,
              size: 38,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Vehicles Found',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please add a vehicle first before logging fuel.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
          const SizedBox(height: 28),
          GradientButton(
            label: 'Go to Vehicles',
            onPressed: () => Navigator.pop(context),
            colors: [AppColors.emerald, AppColors.ocean],
          ),
        ],
      ),
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
              return 'Max allowed: ${max.toStringAsFixed(1)} L (quota or wallet limit)';
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
        gradient: affordable
            ? [
                AppColors.emerald.withOpacity(0.12),
                AppColors.ocean.withOpacity(0.10),
              ].asGradient()
            : [
                AppColors.error.withOpacity(0.10),
                AppColors.error.withOpacity(0.06),
              ].asGradient(),
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
                    'Wallet: Rs. ${_walletBalance.toStringAsFixed(2)}  ·  Shortfall: Rs. ${(cost - _walletBalance).toStringAsFixed(2)}',
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
              'Fuel logging is not available for ${_selectedVehicle.fuelType} vehicles (Electric / LPG).',
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

// Extension for gradient from list
extension ListGradient on List<Color> {
  LinearGradient asGradient() {
    return LinearGradient(
      colors: this,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
