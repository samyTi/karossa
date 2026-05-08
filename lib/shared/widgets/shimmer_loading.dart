import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';

/// Widget de chargement avec effet shimmer pour les listes
class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: AppColors.border,
    highlightColor: AppColors.inputFill,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    ),
  );
}

/// Widget de chargement pour une carte véhicule
class VehiculeCardShimmer extends StatelessWidget {
  const VehiculeCardShimmer({super.key});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        ShimmerLoading(width: 80, height: 60, borderRadius: BorderRadius.circular(8)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerLoading(width: 140, height: 16),
            const SizedBox(height: 8),
            ShimmerLoading(width: 100, height: 12),
            const SizedBox(height: 8),
            Row(children: [
              ShimmerLoading(width: 60, height: 20),
              const SizedBox(width: 6),
              ShimmerLoading(width: 60, height: 20),
            ]),
          ],
        )),
        const SizedBox(width: 8),
        ShimmerLoading(width: 20, height: 20, borderRadius: BorderRadius.circular(4)),
      ]),
    ),
  );
}

/// Widget de chargement pour une liste de véhicules
class VehiculesListShimmer extends StatelessWidget {
  final int itemCount;

  const VehiculesListShimmer({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    itemCount: itemCount,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (_, __) => const VehiculeCardShimmer(),
  );
}

/// Widget de chargement pour une carte client
class ClientCardShimmer extends StatelessWidget {
  const ClientCardShimmer({super.key});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        const ShimmerLoading(width: 48, height: 48, borderRadius: BorderRadius.all(Radius.circular(24))),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerLoading(width: 120, height: 16),
            const SizedBox(height: 6),
            ShimmerLoading(width: 80, height: 12),
          ],
        )),
        const SizedBox(width: 8),
        ShimmerLoading(width: 20, height: 20, borderRadius: BorderRadius.circular(4)),
      ]),
    ),
  );
}

/// Widget de chargement pour une liste de clients
class ClientsListShimmer extends StatelessWidget {
  final int itemCount;

  const ClientsListShimmer({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    itemCount: itemCount,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (_, __) => const ClientCardShimmer(),
  );
}

/// Widget de chargement pour une carte de location
class LocationCardShimmer extends StatelessWidget {
  const LocationCardShimmer({super.key});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        const ShimmerLoading(width: 48, height: 48, borderRadius: BorderRadius.all(Radius.circular(24))),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerLoading(width: 120, height: 16),
            const SizedBox(height: 6),
            ShimmerLoading(width: 80, height: 12),
          ],
        )),
        const SizedBox(width: 8),
        ShimmerLoading(width: 50, height: 30),
      ]),
    ),
  );
}

/// Widget de chargement pour une liste de locations
class LocationsListShimmer extends StatelessWidget {
  final int itemCount;

  const LocationsListShimmer({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    itemCount: itemCount,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (_, __) => const LocationCardShimmer(),
  );
}