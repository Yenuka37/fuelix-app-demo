import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/quota_model.dart';
import '../services/quota_service.dart';
import '../database/db_helper.dart';
import '../widgets/custom_button.dart';

// ─── Static data ──────────────────────────────────────────────────────────────
const _kVehicleTypes = [
  'Car',
  'Motorcycle',
  'Van',
  'Truck',
  'Bus',
  'Three-Wheeler',
];
const _kFuelTypes = ['Petrol', 'Diesel', 'Electric', 'Hybrid', 'LPG'];
const _kMakes = [
  'Toyota',
  'Honda',
  'Suzuki',
  'Nissan',
  'Mitsubishi',
  'Mazda',
  'Hyundai',
  'Kia',
  'BMW',
  'Mercedes-Benz',
  'Volkswagen',
  'Ford',
  'Bajaj',
  'TVS',
  'Hero',
  'Yamaha',
  'Kawasaki',
  'Tata',
  'Other',
];

// ── Fuel pass code generator (8 chars, 0-9 A-Z, globally unique) ──────────────
const _kCodeChars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

String _generatePassCode() {
  final rng = Random.secure();
  return List.generate(
    8,
    (_) => _kCodeChars[rng.nextInt(_kCodeChars.length)],
  ).join();
}

// ── Colour / icon helpers (shared across widgets) ─────────────────────────────
Color vehicleTypeColor(String type) {
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

IconData vehicleTypeIcon(String type) {
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

// ═════════════════════════════════════════════════════════════════════════════
// VehiclesScreen
// ═════════════════════════════════════════════════════════════════════════════
class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});
  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen>
    with SingleTickerProviderStateMixin {
  final _db = DbHelper();
  UserModel? _user;
  List<VehicleModel> _vehicles = [];
  bool _loading = true;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final u = ModalRoute.of(context)?.settings.arguments as UserModel?;
    if (_user == null && u != null) {
      _user = u;
      _loadVehicles();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    if (_user?.id == null) {
      setState(() => _loading = false);
      return;
    }
    final list = await _db.getVehiclesByUser(_user!.id!);
    if (mounted) {
      setState(() {
        _vehicles = list;
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    }
  }

  // ── Add / Edit form ───────────────────────────────────────────────────────
  Future<void> _openForm({VehicleModel? vehicle}) async {
    // Locked vehicles cannot be edited
    if (vehicle?.isLocked == true) {
      _showFuelPass(vehicle!);
      return;
    }
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _VehicleFormSheet(user: _user!, vehicle: vehicle, db: _db),
    );
    if (result == true) _loadVehicles();
  }

  // ── Fuel Pass QR dialog ───────────────────────────────────────────────────
  void _showFuelPass(VehicleModel v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FuelPassSheet(vehicle: v),
    );
  }

  // ── Generate QR confirm ───────────────────────────────────────────────────
  Future<void> _confirmGenerateQr(VehicleModel v) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [AppColors.emerald, AppColors.ocean],
                ),
              ),
              child: const Icon(
                Icons.qr_code_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Generate Fuel Pass',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A unique QR Fuel Pass will be generated for:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.amber.withOpacity(isDark ? 0.12 : 0.08),
                border: Border.all(color: AppColors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.amber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Once generated, vehicle details cannot be edited and this QR cannot be regenerated.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.amber,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.spaceGrotesk(
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Generate',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.emerald,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    // Generate a globally unique code
    String code;
    do {
      code = _generatePassCode();
    } while (await _db.fuelPassCodeExists(code));

    final success = await _db.setFuelPassCode(v.id!, code, v.type);
    if (!mounted) return;

    if (success) {
      await _loadVehicles();
      // Show the fuel pass immediately
      final updated = _vehicles.firstWhere((x) => x.id == v.id);
      _showFuelPass(updated);
    } else {
      showAppSnackbar(
        context,
        message: 'Failed to generate. Try again.',
        isError: true,
      );
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(VehicleModel v) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove Vehicle',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Text(
          'Remove ${v.displayName} (${v.registrationNo}) from your garage?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.spaceGrotesk(
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteVehicle(v.id!);
      _loadVehicles();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: _iconBtn(Icons.arrow_back_ios_new_rounded, isDark),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'My Vehicles',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    GestureDetector(
                      onTap: _user != null ? () => _openForm() : null,
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [AppColors.emerald, AppColors.ocean],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emerald.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Add',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // List
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.emerald,
                          strokeWidth: 2,
                        ),
                      )
                    : _vehicles.isEmpty
                    ? _EmptyGarage(isDark: isDark, onAdd: () => _openForm())
                    : FadeTransition(
                        opacity: _fadeAnim,
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                          itemCount: _vehicles.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _VehicleCard(
                            vehicle: _vehicles[i],
                            isDark: isDark,
                            onEdit: () => _openForm(vehicle: _vehicles[i]),
                            onDelete: () => _confirmDelete(_vehicles[i]),
                            onGenerateQr: () =>
                                _confirmGenerateQr(_vehicles[i]),
                            onViewFuelPass: () => _showFuelPass(_vehicles[i]),
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

  Widget _iconBtn(IconData icon, bool isDark) => Container(
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
// Vehicle Card
// ═════════════════════════════════════════════════════════════════════════════
class _VehicleCard extends StatelessWidget {
  final VehicleModel vehicle;
  final bool isDark;
  final VoidCallback onEdit, onDelete, onGenerateQr, onViewFuelPass;

  const _VehicleCard({
    required this.vehicle,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    required this.onGenerateQr,
    required this.onViewFuelPass,
  });

  @override
  Widget build(BuildContext context) {
    final accent = vehicleTypeColor(vehicle.type);
    final locked = vehicle.isLocked;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: locked
              ? AppColors.emerald.withOpacity(0.35)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: locked ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (locked ? AppColors.emerald : accent).withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                // Type icon
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        gradient: LinearGradient(
                          colors: [accent, accent.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        vehicleTypeIcon(vehicle.type),
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    // Lock badge if QR generated
                    if (locked)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.emerald,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkSurface
                                  : AppColors.lightSurface,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 9,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.displayName,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Tag(
                            label: vehicle.registrationNo,
                            color: accent,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _Tag(
                            label: vehicle.fuelType,
                            color: AppColors.emerald,
                            isDark: isDark,
                          ),
                          if (locked) ...[
                            const SizedBox(width: 6),
                            _Tag(
                              label: 'FUEL PASS',
                              color: AppColors.emerald,
                              isDark: isDark,
                              icon: Icons.qr_code_rounded,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Menu
                PopupMenuButton<String>(
                  onSelected: (val) {
                    switch (val) {
                      case 'qr':
                        onGenerateQr();
                        break;
                      case 'pass':
                        onViewFuelPass();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: isDark
                        ? AppColors.darkTextSub
                        : AppColors.lightTextSub,
                  ),
                  itemBuilder: (_) => [
                    if (!locked) ...[
                      _menuItem(
                        'qr',
                        Icons.qr_code_rounded,
                        'Generate Fuel Pass',
                        AppColors.emerald,
                      ),
                      _menuItem(
                        'edit',
                        Icons.edit_outlined,
                        'Edit',
                        AppColors.ocean,
                      ),
                    ],
                    if (locked)
                      _menuItem(
                        'pass',
                        Icons.qr_code_2_rounded,
                        'View Fuel Pass',
                        AppColors.emerald,
                      ),
                    _menuItem(
                      'delete',
                      Icons.delete_outline_rounded,
                      'Remove',
                      AppColors.error,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Details row ────────────────────────────────────────────────
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                _Chip(
                  icon: Icons.category_outlined,
                  label: vehicle.type,
                  isDark: isDark,
                ),
                if (vehicle.engineCC.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _Chip(
                    icon: Icons.settings_rounded,
                    label: '${vehicle.engineCC} cc',
                    isDark: isDark,
                  ),
                ],
                if (vehicle.color.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _Chip(
                    icon: Icons.circle_rounded,
                    label: vehicle.color,
                    isDark: isDark,
                  ),
                ],
                const Spacer(),
                // Quick action button
                if (!locked)
                  GestureDetector(
                    onTap: onGenerateQr,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [AppColors.emerald, AppColors.ocean],
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.qr_code_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Get Fuel Pass',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: onViewFuelPass,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.emerald.withOpacity(
                          isDark ? 0.15 : 0.10,
                        ),
                        border: Border.all(
                          color: AppColors.emerald.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.qr_code_2_rounded,
                            size: 13,
                            color: AppColors.emerald,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'View Pass',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String val,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Fuel Pass Bottom-Sheet  (StatefulWidget — loads live quota)
// ═════════════════════════════════════════════════════════════════════════════
class _FuelPassSheet extends StatefulWidget {
  final VehicleModel vehicle;
  const _FuelPassSheet({required this.vehicle});
  @override
  State<_FuelPassSheet> createState() => _FuelPassSheetState();
}

class _FuelPassSheetState extends State<_FuelPassSheet> {
  final _db = DbHelper();
  FuelQuotaModel? _quota;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  Future<void> _loadQuota() async {
    if (widget.vehicle.id == null) {
      setState(() => _loading = false);
      return;
    }
    final q = await _db.getCurrentWeekQuota(
      widget.vehicle.id!,
      widget.vehicle.type,
    );
    if (mounted)
      setState(() {
        _quota = q;
        _loading = false;
      });
  }

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = vehicleTypeColor(widget.vehicle.type);
    final code = widget.vehicle.fuelPassCode ?? '';
    final qrData =
        'FUELIX|${widget.vehicle.fuelPassCode}|${widget.vehicle.registrationNo}|'
        '${widget.vehicle.make} ${widget.vehicle.model}'
        '|${widget.vehicle.year}|${widget.vehicle.fuelType}';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            const SizedBox(height: 20),

            // ── Pass card ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      accent,
                      accent.withOpacity(0.75),
                      AppColors.ocean.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white.withOpacity(0.2),
                            ),
                            child: Icon(
                              vehicleTypeIcon(widget.vehicle.type),
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FUEL PASS',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.75),
                                    letterSpacing: 2,
                                  ),
                                ),
                                Text(
                                  widget.vehicle.displayName,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white.withOpacity(0.15),
                            ),
                            child: Text(
                              'FUELIX',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // White QR area
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 22),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 175,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF111827),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFFF3F4F6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${code.substring(0, 4)} ${code.substring(4)}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF111827),
                                    letterSpacing: 4,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: code),
                                    );
                                    showAppSnackbar(
                                      context,
                                      message: 'Code copied!',
                                      isSuccess: true,
                                    );
                                  },
                                  child: const Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Vehicle details strip
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                      child: Row(
                        children: [
                          Expanded(
                            child: _PassDetail(
                              label: 'REG NO',
                              value: widget.vehicle.registrationNo,
                            ),
                          ),
                          Expanded(
                            child: _PassDetail(
                              label: 'FUEL TYPE',
                              value: widget.vehicle.fuelType,
                            ),
                          ),
                          Expanded(
                            child: _PassDetail(
                              label: 'ISSUED',
                              value: widget.vehicle.qrGeneratedAt != null
                                  ? _formatDate(widget.vehicle.qrGeneratedAt!)
                                  : '—',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Weekly Quota Card ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: AppColors.emerald,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : _quota != null
                  ? _QuotaCard(
                      quota: _quota!,
                      vehicleType: widget.vehicle.type,
                      isDark: isDark,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // ── Info notice ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _Notice(
                icon: Icons.info_outline_rounded,
                color: AppColors.ocean,
                isDark: isDark,
                text:
                    'Show this QR code at fuel stations to authorise refuelling. '
                    'This pass is unique to this vehicle and cannot be transferred.',
              ),
            ),
            const SizedBox(height: 12),

            // ── Lock notice ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: _Notice(
                icon: Icons.lock_rounded,
                color: AppColors.amber,
                isDark: isDark,
                text:
                    'Vehicle details are locked. '
                    'The Fuel Pass code cannot be regenerated.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Weekly Quota Card ────────────────────────────────────────────────────────
class _QuotaCard extends StatelessWidget {
  final FuelQuotaModel quota;
  final String vehicleType;
  final bool isDark;

  const _QuotaCard({
    required this.quota,
    required this.vehicleType,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = quota.remainingLitres;
    final used = quota.usedLitres;
    final total = quota.quotaLitres;
    final pct = quota.usedPercent;
    final exhausted = quota.isExhausted;

    // Gauge colour: green → amber → red as usage grows
    Color gaugeColor;
    if (pct < 0.5)
      gaugeColor = AppColors.emerald;
    else if (pct < 0.85)
      gaugeColor = AppColors.amber;
    else
      gaugeColor = AppColors.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: exhausted
              ? AppColors.error.withOpacity(0.4)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: exhausted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: exhausted
                        ? [AppColors.error, AppColors.error.withOpacity(0.7)]
                        : [AppColors.emerald, AppColors.ocean],
                  ),
                ),
                child: Icon(
                  exhausted
                      ? Icons.no_meals_rounded
                      : Icons.local_gas_station_rounded,
                  size: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Fuel Quota',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    Text(
                      QuotaService.weekLabel(quota.weekStart),
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
              // Days remaining badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: (exhausted ? AppColors.error : AppColors.emerald)
                      .withOpacity(isDark ? 0.15 : 0.10),
                  border: Border.all(
                    color: (exhausted ? AppColors.error : AppColors.emerald)
                        .withOpacity(0.35),
                  ),
                ),
                child: Text(
                  exhausted
                      ? 'Exhausted'
                      : QuotaService.daysRemainingLabel(now),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: exhausted ? AppColors.error : AppColors.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Big numbers row ───────────────────────────────────────────
          Row(
            children: [
              _QuotaStat(
                label: 'Remaining',
                value: '${remaining.toStringAsFixed(1)} L',
                color: exhausted ? AppColors.error : AppColors.emerald,
                isDark: isDark,
                large: true,
              ),
              _vDivider(isDark),
              _QuotaStat(
                label: 'Used',
                value: '${used.toStringAsFixed(1)} L',
                color: AppColors.amber,
                isDark: isDark,
              ),
              _vDivider(isDark),
              _QuotaStat(
                label: 'Weekly Total',
                value: '${total.toStringAsFixed(0)} L',
                color: AppColors.ocean,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Progress bar ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 10,
                        backgroundColor: isDark
                            ? AppColors.darkSurfaceAlt
                            : AppColors.lightSurfaceAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}% used',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                        Text(
                          'Resets next Monday',
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
              ),
            ],
          ),

          // ── Exhausted notice ──────────────────────────────────────────
          if (exhausted) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.error.withOpacity(isDark ? 0.12 : 0.07),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 15,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your weekly quota is exhausted. '
                      'Balance resets every Monday.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.error,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vDivider(bool isDark) => Container(
    width: 1,
    height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
  );
}

class _QuotaStat extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark, large;
  const _QuotaStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: large ? 22 : 17,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final String text;
  const _Notice({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.text,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: color.withOpacity(isDark ? 0.08 : 0.05),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 12, color: color, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class _PassDetail extends StatelessWidget {
  final String label, value;
  const _PassDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.65),
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Add / Edit Form Sheet
// ═════════════════════════════════════════════════════════════════════════════
class _VehicleFormSheet extends StatefulWidget {
  final UserModel user;
  final VehicleModel? vehicle;
  final DbHelper db;
  const _VehicleFormSheet({required this.user, required this.db, this.vehicle});

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _regCtrl = TextEditingController();
  final _engCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();

  String? _type;
  String? _fuelType;
  bool _isLoading = false;

  bool get _isEdit => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    if (v != null) {
      _type = v.type;
      _fuelType = v.fuelType;
      _makeCtrl.text = v.make;
      _modelCtrl.text = v.model;
      _yearCtrl.text = v.year;
      _regCtrl.text = v.registrationNo;
      _engCtrl.text = v.engineCC;
      _colorCtrl.text = v.color;
    }
  }

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _regCtrl.dispose();
    _engCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fuelType == null) {
      showAppSnackbar(
        context,
        message: 'Please select a fuel type.',
        isError: true,
      );
      return;
    }
    setState(() => _isLoading = true);

    final userId = widget.user.id ?? 0;
    final regNo = _regCtrl.text.trim().toUpperCase();

    final exists = await widget.db.regNoExists(
      regNo,
      userId,
      excludeId: widget.vehicle?.id,
    );
    if (!mounted) return;
    if (exists) {
      setState(() => _isLoading = false);
      showAppSnackbar(
        context,
        message: 'Registration number already added.',
        isError: true,
      );
      return;
    }

    final vehicle = VehicleModel(
      id: widget.vehicle?.id,
      userId: userId,
      type: _type!,
      make: _makeCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      year: _yearCtrl.text.trim(),
      registrationNo: regNo,
      fuelType: _fuelType!,
      engineCC: _engCtrl.text.trim(),
      color: _colorCtrl.text.trim(),
      createdAt: widget.vehicle?.createdAt ?? DateTime.now(),
    );

    final result = _isEdit
        ? await widget.db.updateVehicle(vehicle)
        : await widget.db.insertVehicle(vehicle);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result > 0 || (result >= 0 && _isEdit)) {
      showAppSnackbar(
        context,
        message: _isEdit ? 'Vehicle updated!' : 'Vehicle added to your garage!',
        isSuccess: true,
      );
      Navigator.pop(context, true);
    } else {
      showAppSnackbar(
        context,
        message: 'Failed to save. Try again.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);

    return Container(
      margin: EdgeInsets.only(top: mq.size.height * 0.08),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [AppColors.emerald, AppColors.ocean],
                    ),
                  ),
                  child: Icon(
                    _isEdit ? Icons.edit_rounded : Icons.add_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isEdit ? 'Edit Vehicle' : 'Add Vehicle',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isDark
                          ? AppColors.darkSurfaceAlt
                          : AppColors.lightSurfaceAlt,
                    ),
                    child: Icon(
                      Icons.close_rounded,
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
          // Form
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                mq.viewInsets.bottom + 32,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Vehicle Type', isDark),
                    _Dropdown(
                      label: 'Type',
                      value: _type,
                      items: _kVehicleTypes,
                      icon: Icons.category_outlined,
                      isDark: isDark,
                      onChanged: (v) => setState(() => _type = v),
                      validator: (v) =>
                          v == null ? 'Select vehicle type' : null,
                    ),
                    const SizedBox(height: 16),
                    _Label('Make & Model', isDark),
                    _Dropdown(
                      label: 'Make / Brand',
                      value: _kMakes.contains(_makeCtrl.text)
                          ? _makeCtrl.text
                          : null,
                      items: _kMakes,
                      icon: Icons.branding_watermark_outlined,
                      isDark: isDark,
                      onChanged: (v) =>
                          setState(() => _makeCtrl.text = v ?? ''),
                      validator: (v) => v == null ? 'Select make' : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Model',
                      hint: 'e.g. Corolla, Civic',
                      controller: _modelCtrl,
                      prefixIcon: Icons.directions_car_outlined,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Model is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _Label('Year & Registration', isDark),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            label: 'Year',
                            hint: '2020',
                            controller: _yearCtrl,
                            prefixIcon: Icons.calendar_today_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Required';
                              final y = int.tryParse(v.trim());
                              if (y == null ||
                                  y < 1950 ||
                                  y > DateTime.now().year + 1)
                                return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: AppTextField(
                            label: 'Registration No.',
                            hint: 'WP CAB-1234',
                            controller: _regCtrl,
                            prefixIcon: Icons.confirmation_number_outlined,
                            textCapitalization: TextCapitalization.characters,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Label('Fuel Type', isDark),
                    _FuelPills(
                      selected: _fuelType,
                      isDark: isDark,
                      onSelect: (f) => setState(() => _fuelType = f),
                    ),
                    if (_fuelType == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          'Select a fuel type',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _Label('Additional Details (Optional)', isDark),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Engine (cc)',
                            hint: '1500',
                            controller: _engCtrl,
                            prefixIcon: Icons.settings_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Color',
                            hint: 'Silver',
                            controller: _colorCtrl,
                            prefixIcon: Icons.palette_outlined,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    GradientButton(
                      label: _isEdit ? 'Update Vehicle' : 'Add to Garage',
                      onPressed: _save,
                      isLoading: _isLoading,
                      colors: [AppColors.emerald, AppColors.ocean],
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
}

// ─── Small helpers ────────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  final IconData? icon;
  const _Tag({
    required this.label,
    required this.color,
    required this.isDark,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      color: color.withOpacity(isDark ? 0.15 : 0.10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  const _Chip({required this.icon, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 13,
        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
        ),
      ),
    ],
  );
}

class _EmptyGarage extends StatelessWidget {
  final bool isDark;
  final VoidCallback onAdd;
  const _EmptyGarage({required this.isDark, required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
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
              size: 40,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No vehicles added',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your vehicles to track fuel consumption and trips.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
          const SizedBox(height: 28),
          GradientButton(
            label: 'Add First Vehicle',
            onPressed: onAdd,
            colors: [AppColors.emerald, AppColors.ocean],
          ),
        ],
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  final bool isDark;
  const _Label(this.text, this.isDark);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        letterSpacing: 0.6,
      ),
    ),
  );
}

class _FuelPills extends StatelessWidget {
  final String? selected;
  final bool isDark;
  final ValueChanged<String> onSelect;
  const _FuelPills({
    required this.selected,
    required this.isDark,
    required this.onSelect,
  });

  Color _col(String f) {
    switch (f) {
      case 'Petrol':
        return AppColors.amber;
      case 'Diesel':
        return AppColors.ocean;
      case 'Electric':
        return AppColors.emerald;
      case 'Hybrid':
        return const Color(0xFF7C3AED);
      case 'LPG':
        return const Color(0xFFEF4444);
      default:
        return AppColors.emerald;
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _kFuelTypes.map((f) {
      final sel = f == selected;
      final c = _col(f);
      return GestureDetector(
        onTap: () => onSelect(f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: sel
                ? c.withOpacity(isDark ? 0.2 : 0.12)
                : (isDark
                      ? AppColors.darkSurfaceAlt
                      : AppColors.lightSurfaceAlt),
            border: Border.all(
              color: sel
                  ? c
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Text(
            f,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: sel
                  ? c
                  : (isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final bool isDark;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.isDark,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final bc = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fc = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final tc = isDark ? AppColors.darkText : AppColors.lightText;
    final hc = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: hc),
      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      style: GoogleFonts.inter(fontSize: 14, color: tc),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          size: 20,
          color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
        ),
        filled: true,
        fillColor: fc,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: bc, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: bc, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.emerald, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      items: items
          .map(
            (i) => DropdownMenuItem(
              value: i,
              child: Text(i, style: GoogleFonts.inter(fontSize: 14, color: tc)),
            ),
          )
          .toList(),
    );
  }
}
