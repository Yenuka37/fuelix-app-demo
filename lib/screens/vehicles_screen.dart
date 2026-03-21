import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
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

// ═════════════════════════════════════════════════════════════════════════════
// VehiclesScreen – list + FAB to add
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

  // ── Open Add / Edit bottom-sheet ──────────────────────────────────────────
  Future<void> _openForm({VehicleModel? vehicle}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _VehicleFormSheet(user: _user!, vehicle: vehicle, db: _db),
    );
    if (result == true) _loadVehicles();
  }

  // ── Delete confirm ────────────────────────────────────────────────────────
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
              // ── Top bar ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: _iconBox(Icons.arrow_back_ios_new_rounded, isDark),
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
              // ── Content ────────────────────────────────────────────────
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
// Vehicle Card
// ═════════════════════════════════════════════════════════════════════════════
class _VehicleCard extends StatelessWidget {
  final VehicleModel vehicle;
  final bool isDark;
  final VoidCallback onEdit, onDelete;
  const _VehicleCard({
    required this.vehicle,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  Color _typeColor(String type) {
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

  IconData _typeIcon(String type) {
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
    final accent = _typeColor(vehicle.type);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                // Type icon badge
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
                    _typeIcon(vehicle.type),
                    size: 22,
                    color: Colors.white,
                  ),
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
                      const SizedBox(height: 3),
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
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
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
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: AppColors.ocean,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Edit',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Remove',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
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
          // ── Details row ────────────────────────────────────────────────
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                _DetailChip(
                  icon: Icons.category_outlined,
                  label: vehicle.type,
                  isDark: isDark,
                ),
                if (vehicle.engineCC.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _DetailChip(
                    icon: Icons.settings_rounded,
                    label: '${vehicle.engineCC} cc',
                    isDark: isDark,
                  ),
                ],
                if (vehicle.color.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _DetailChip(
                    icon: Icons.circle_rounded,
                    label: vehicle.color,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  const _Tag({required this.label, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      color: color.withOpacity(isDark ? 0.15 : 0.10),
    ),
    child: Text(
      label,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

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

// ═════════════════════════════════════════════════════════════════════════════
// Empty state
// ═════════════════════════════════════════════════════════════════════════════
class _EmptyGarage extends StatelessWidget {
  final bool isDark;
  final VoidCallback onAdd;
  const _EmptyGarage({required this.isDark, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
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
}

// ═════════════════════════════════════════════════════════════════════════════
// Add / Edit bottom-sheet form
// ═════════════════════════════════════════════════════════════════════════════
class _VehicleFormSheet extends StatefulWidget {
  final UserModel user;
  final VehicleModel? vehicle; // null = add mode
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
  final _engineCtrl = TextEditingController();
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
      _engineCtrl.text = v.engineCC;
      _colorCtrl.text = v.color;
    }
  }

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _regCtrl.dispose();
    _engineCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final userId = widget.user.id ?? 0;
    final regNo = _regCtrl.text.trim().toUpperCase();

    // Duplicate reg check
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
        message: 'This registration number is already added.',
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
      engineCC: _engineCtrl.text.trim(),
      color: _colorCtrl.text.trim(),
      createdAt: widget.vehicle?.createdAt ?? DateTime.now(),
    );

    int result;
    if (_isEdit) {
      result = await widget.db.updateVehicle(vehicle);
    } else {
      result = await widget.db.insertVehicle(vehicle);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result > 0 || (result >= 0 && _isEdit)) {
      showAppSnackbar(
        context,
        message: _isEdit
            ? 'Vehicle updated successfully!'
            : 'Vehicle added to your garage!',
        isSuccess: true,
      );
      Navigator.pop(context, true);
    } else {
      showAppSnackbar(
        context,
        message: 'Failed to save. Please try again.',
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
          const SizedBox(height: 16),
          // Title row
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
                    // ── Vehicle type ──────────────────────────────────────
                    _FormLabel('Vehicle Type', isDark),
                    _SheetDropdown(
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

                    // ── Make & Model ──────────────────────────────────────
                    _FormLabel('Make & Model', isDark),
                    _SheetDropdown(
                      label: 'Make / Brand',
                      value: _kMakes.contains(_makeCtrl.text)
                          ? _makeCtrl.text
                          : null,
                      items: _kMakes,
                      icon: Icons.branding_watermark_outlined,
                      isDark: isDark,
                      onChanged: (v) => setState(() {
                        _makeCtrl.text = v ?? '';
                      }),
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

                    // ── Year & Reg ────────────────────────────────────────
                    _FormLabel('Year & Registration', isDark),
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
                                  y > DateTime.now().year + 1) {
                                return 'Invalid year';
                              }
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

                    // ── Fuel type ─────────────────────────────────────────
                    _FormLabel('Fuel Type', isDark),
                    _FuelTypeSelector(
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

                    // ── Engine & Color (optional) ─────────────────────────
                    _FormLabel('Additional Details (Optional)', isDark),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Engine (cc)',
                            hint: '1500',
                            controller: _engineCtrl,
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

                    // ── Save button ───────────────────────────────────────
                    GradientButton(
                      label: _isEdit ? 'Update Vehicle' : 'Add to Garage',
                      onPressed: () {
                        if (_fuelType == null) {
                          showAppSnackbar(
                            context,
                            message: 'Please select a fuel type.',
                            isError: true,
                          );
                          return;
                        }
                        _save();
                      },
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

// ─── Fuel type pill selector ──────────────────────────────────────────────────
class _FuelTypeSelector extends StatelessWidget {
  final String? selected;
  final bool isDark;
  final ValueChanged<String> onSelect;

  const _FuelTypeSelector({
    required this.selected,
    required this.isDark,
    required this.onSelect,
  });

  Color _color(String f) {
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
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _kFuelTypes.map((f) {
        final isSelected = f == selected;
        final color = _color(f);
        return GestureDetector(
          onTap: () => onSelect(f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
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
            child: Text(
              f,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? color
                    : (isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Form section label ───────────────────────────────────────────────────────
class _FormLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _FormLabel(this.text, this.isDark);

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

// ─── Sheet Dropdown ───────────────────────────────────────────────────────────
class _SheetDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final bool isDark;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _SheetDropdown({
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
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fillColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final hintColor = isDark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;

    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      onChanged: onChanged,
      validator: validator,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: hintColor),
      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      style: GoogleFonts.inter(fontSize: 14, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          size: 20,
          color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor, width: 1.5),
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
              child: Text(
                i,
                style: GoogleFonts.inter(fontSize: 14, color: textColor),
              ),
            ),
          )
          .toList(),
    );
  }
}
