// lib/core/utils/dependency_injection.dart

import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/goalkeeper_passes_repository.dart';

// Importaciones locales
import 'package:goalkeeper_stats/data/repositories/local_auth_repository.dart';
import 'package:goalkeeper_stats/data/repositories/local_shots_repository.dart';
import 'package:goalkeeper_stats/data/repositories/local_matches_repository.dart';
import 'package:goalkeeper_stats/data/repositories/local_goalkeeper_passes_repository.dart';

// Importaciones de Firebase (se implementarán después)
import 'package:goalkeeper_stats/data/repositories/firebase_auth_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_shots_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_matches_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_goalkeeper_passes_repository.dart';

enum StorageMode {
  local,
  firebase,
}

class DependencyInjection {
  static final DependencyInjection _instance = DependencyInjection._internal();

  factory DependencyInjection() => _instance;

  DependencyInjection._internal();

  // Por defecto, usar almacenamiento local
  StorageMode _currentMode = StorageMode.local;

  // Getters para los repositorios
  AuthRepository get authRepository => _currentMode == StorageMode.local
      ? LocalAuthRepository()
      : FirebaseAuthRepository();

  ShotsRepository get shotsRepository => _currentMode == StorageMode.local
      ? LocalShotsRepository()
      : FirebaseShotsRepository();

  MatchesRepository get matchesRepository => _currentMode == StorageMode.local
      ? LocalMatchesRepository()
      : FirebaseMatchesRepository();

  GoalkeeperPassesRepository get passesRepository =>
      _currentMode == StorageMode.firebase
          ? LocalGoalkeeperPassesRepository()
          : FirebaseGoalkeeperPassesRepository();

  // Método para cambiar el modo de almacenamiento
  void setStorageMode(StorageMode mode) {
    _currentMode = mode;
  }

  // Verificar si Firebase está disponible
  Future<bool> isFirebaseAvailable() async {
    try {
      // Aquí podríamos hacer una verificación simple de Firebase
      // Por ejemplo, intentar inicializar Firebase
      return false; // Por ahora, devolver false
    } catch (e) {
      return false;
    }
  }
}
