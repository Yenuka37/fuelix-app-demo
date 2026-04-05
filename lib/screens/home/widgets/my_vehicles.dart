import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/vehicle_model.dart';

class MyVehicles extends StatelessWidget {
  final List<VehicleModel> vehicles;
  final bool isDark;
  final VoidCallback onManageTap;

  const MyVehicles({
    super.key,
    required this.vehicles,
    required this.isDark,
    required this.onManageTap,
  });

  @override
  Widget build(BuildContext context) {
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
              onTap: onManageTap,
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
        if (vehicles.isEmpty)
          _EmptyGarage(isDark: isDark, onAdd: onManageTap)
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: vehicles.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                if (i == vehicles.length) {
                  return _AddVehicleCard(isDark: isDark, onTap: onManageTap);
                }
                return _VehicleChip(vehicle: vehicles[i], isDark: isDark);
              },
            ),
          ),
      ],
    );
  }
}

Color _vehicleTypeColor(String type) {
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

IconData _vehicleTypeIcon(String type) {
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

class _VehicleChip extends StatelessWidget {
  final VehicleModel vehicle;
  final bool isDark;
  const _VehicleChip({required this.vehicle, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final accent = _vehicleTypeColor(vehicle.type);
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
                child: Icon(
                  _vehicleTypeIcon(vehicle.type),
                  size: 16,
                  color: Colors.white,
                ),
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

class _AddVehicleCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _AddVehicleCard({required this.isDark, required this.onTap});

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

class _EmptyGarage extends StatelessWidget {
  final bool isDark;
  final VoidCallback onAdd;
  const _EmptyGarage({required this.isDark, required this.onAdd});

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
