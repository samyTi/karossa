import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contrat_model.dart';

final contratProvider = StateProvider<List<ContratModel>>((ref) {
  return [];
});