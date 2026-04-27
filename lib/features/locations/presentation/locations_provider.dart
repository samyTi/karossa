import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/locations_repository.dart';
import '../domain/location_model.dart';

final locationsRepositoryProvider = Provider((_) => LocationsRepository());

final locationsActivesProvider =
    FutureProvider.autoDispose<List<Location>>((ref) {
  return ref.watch(locationsRepositoryProvider).getActives();
});

final locationsRetardProvider =
    FutureProvider.autoDispose<List<Location>>((ref) {
  return ref.watch(locationsRepositoryProvider).getRetards();
});
