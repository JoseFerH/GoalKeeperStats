// lib/core/utils/dependency_injection.dart

import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/goalkeeper_passes_repository.dart';

// Local
import 'package:goalkeeper_stats/data/repositories/local_auth_repository.dart';
import 'package:goalkeeper_stats/data/repositories/local_shots_repository.dart';
import 'package:goalkeeper_stats/data/repositories/local_matches_repository.dart';
import 'package:goalkeeper_stats/data/repositories/local_goalkeeper_passes_repository.dart';

// Firebase
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

  StorageMode _currentMode = StorageMode.local;
  AuthRepository? _cachedAuthRepository;

  // Repositorios
  AuthRepository get authRepository {
    if (_cachedAuthRepository != null) return _cachedAuthRepository!;
    
    _cachedAuthRepository = _currentMode == StorageMode.local
        ? LocalAuthRepository()
        : FirebaseAuthRepository();
    return _cachedAuthRepository!;
  }

  ShotsRepository get shotsRepository => _currentMode == StorageMode.local
      ? LocalShotsRepository()
      : FirebaseShotsRepository(authRepository: authRepository);

  MatchesRepository get matchesRepository => _currentMode == StorageMode.local
      ? LocalMatchesRepository()
      : FirebaseMatchesRepository(authRepository: authRepository);

  GoalkeeperPassesRepository get passesRepository => _currentMode == StorageMode.local
      ? LocalGoalkeeperPassesRepository()
      : FirebaseGoalkeeperPassesRepository(authRepository: authRepository);

  void setStorageMode(StorageMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      _cachedAuthRepository = null; // Reset auth repository on mode change
    }
  }

  Future<bool> isFirebaseAvailable() async {
    try {
      // Implementación real de verificación de Firebase
      return true;
    } catch (e) {
      return false;
    }
  }
}