import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/match_model.dart';

/// Administrador de caché para almacenar y recuperar datos localmente
///
/// Permite guardar objetos en caché con tiempo de expiración para mejorar
/// el rendimiento y proporcionar funcionalidad sin conexión.
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  SharedPreferences? _prefs;
  final Map<String, dynamic> _memoryCache = {};

  // Prefijo para claves de caché
  static const String _cacheKeyPrefix = 'cache_';
  static const String _expireKeyPrefix = 'expire_';

  /// Constructor de fábrica para el patrón singleton
  factory CacheManager() {
    return _instance;
  }

  /// Constructor privado para inicialización interna
  CacheManager._internal();

  /// Inicializar el administrador de caché
  Future<void> init() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
      _cleanExpiredCache();
    }
  }

  /// Almacena un valor en caché con tiempo de expiración opcional
  ///
  /// [key] - Clave única para identificar el valor
  /// [value] - Valor a almacenar (debe ser serializable)
  /// [duration] - Duración en segundos antes de que expire (opcional)
  Future<bool> set<T>(String key, T value, {int duration = 86400}) async {
    if (!_isInitialized()) {
      await init();
    }

    try {
      // Calcular tiempo de expiración
      final expireTime = DateTime.now()
          .add(Duration(seconds: duration))
          .millisecondsSinceEpoch;

      // Almacenar en memoria para acceso rápido
      _memoryCache[key] = value;

      // Serializar el valor según su tipo
      String jsonValue;
      String valueType = T.toString();

      // 🔧 CORRECCIÓN: Manejo mejorado de tipos
      if (value is UserModel) {
        jsonValue = json.encode(value.toJson());
        valueType = 'UserModel';
      } else if (value is MatchModel) {
        jsonValue = json.encode(value.toMap());
        valueType = 'MatchModel';
      } else if (value is List<MatchModel>) {
        // 🔧 CORRECCIÓN PRINCIPAL: Manejo correcto de listas de MatchModel
        final listData = value.map((match) => match.toMap()).toList();
        jsonValue = json.encode(listData);
        valueType = 'List<MatchModel>';
      } else if (value is List) {
        // Para otras listas
        jsonValue = json.encode(value);
        valueType = 'List';
      } else if (_isBasicType(value)) {
        jsonValue = value.toString();
        valueType = value.runtimeType.toString();
      } else {
        // Para otros tipos complejos
        jsonValue = json.encode(value);
        valueType = value.runtimeType.toString();
      }

      // Guardar en persistencia con información de tipo
      final cacheData = {
        'value': jsonValue,
        'type': valueType,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };

      // Guardar datos y tiempo de expiración
      await _prefs!.setString('$_cacheKeyPrefix$key', json.encode(cacheData));
      await _prefs!.setInt('$_expireKeyPrefix$key', expireTime);

      return true;
    } catch (e) {
      print('❌ Error al guardar en caché: $e');
      return false;
    }
  }

  /// Recupera un valor de la caché
  ///
  /// [key] - Clave del valor a recuperar
  /// Retorna null si la clave no existe o está expirada
  Future<T?> get<T>(String key) async {
    if (!_isInitialized()) {
      await init();
    }

    try {
      // Verificar si hay valor en memoria
      if (_memoryCache.containsKey(key)) {
        final value = _memoryCache[key];
        if (value is T) {
          return value;
        }
      }

      // Verificar si ha expirado
      final expireTime = _prefs!.getInt('$_expireKeyPrefix$key');
      if (expireTime == null ||
          expireTime < DateTime.now().millisecondsSinceEpoch) {
        // Caché expirada o inexistente
        return null;
      }

      // Recuperar de persistencia
      final data = _prefs!.getString('$_cacheKeyPrefix$key');
      if (data == null) {
        return null;
      }

      // Decodificar datos
      final cacheData = json.decode(data);
      final valueString = cacheData['value'];
      final type = cacheData['type'];

      // 🔧 CORRECCIÓN: Deserialización mejorada
      dynamic deserializedValue;

      if (type == 'UserModel' && T == UserModel) {
        deserializedValue = UserModel.fromJson(json.decode(valueString));
      } else if (type == 'MatchModel' && T == MatchModel) {
        final matchData = json.decode(valueString);
        deserializedValue =
            MatchModel.fromMap(matchData, matchData['id'] ?? '');
      } else if (type == 'List<MatchModel>') {
        // 🔧 CORRECCIÓN PRINCIPAL: Deserialización correcta de listas de MatchModel
        final listData = json.decode(valueString) as List;
        deserializedValue = listData.map((matchData) {
          return MatchModel.fromMap(matchData, matchData['id'] ?? '');
        }).toList();
      } else if (type == 'List') {
        deserializedValue = json.decode(valueString);
      } else if (type == 'String' ||
          type == 'int' ||
          type == 'double' ||
          type == 'bool') {
        // Tipos básicos
        if (type == 'int') {
          deserializedValue = int.tryParse(valueString) ?? 0;
        } else if (type == 'double') {
          deserializedValue = double.tryParse(valueString) ?? 0.0;
        } else if (type == 'bool') {
          deserializedValue = valueString.toLowerCase() == 'true';
        } else {
          deserializedValue = valueString;
        }
      } else {
        // Para otros tipos complejos
        deserializedValue = json.decode(valueString);
      }

      // Actualizar caché en memoria
      _memoryCache[key] = deserializedValue;

      if (deserializedValue is T) {
        return deserializedValue as T;
      }

      return null;
    } catch (e) {
      print('❌ Error al recuperar de caché: $e');
      return null;
    }
  }

  /// Elimina un valor de la caché
  ///
  /// [key] - Clave del valor a eliminar
  Future<bool> remove(String key) async {
    if (!_isInitialized()) {
      await init();
    }

    try {
      // Eliminar de memoria
      _memoryCache.remove(key);

      // Eliminar de persistencia
      await _prefs!.remove('$_cacheKeyPrefix$key');
      await _prefs!.remove('$_expireKeyPrefix$key');

      return true;
    } catch (e) {
      print('❌ Error al eliminar de caché: $e');
      return false;
    }
  }

  /// Limpia toda la caché
  Future<bool> clear() async {
    if (!_isInitialized()) {
      await init();
    }

    try {
      // Limpiar memoria
      _memoryCache.clear();

      // Obtener todas las claves de caché
      final keys = _prefs!
          .getKeys()
          .where((key) =>
              key.startsWith(_cacheKeyPrefix) ||
              key.startsWith(_expireKeyPrefix))
          .toList();

      // Eliminar todas las claves
      for (final key in keys) {
        await _prefs!.remove(key);
      }

      return true;
    } catch (e) {
      print('❌ Error al limpiar caché: $e');
      return false;
    }
  }

  /// Verifica si el administrador de caché está inicializado
  bool _isInitialized() {
    return _prefs != null;
  }

  /// Limpia entradas de caché expiradas
  Future<void> _cleanExpiredCache() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // Obtener todas las claves de expiración
      final expireKeys = _prefs!
          .getKeys()
          .where((key) => key.startsWith(_expireKeyPrefix))
          .toList();

      // Verificar cada clave
      for (final expireKey in expireKeys) {
        final expireTime = _prefs!.getInt(expireKey);

        if (expireTime != null && expireTime < now) {
          // Extraer la clave base
          final baseKey = expireKey.substring(_expireKeyPrefix.length);

          // Eliminar clave expirada
          await _prefs!.remove('$_cacheKeyPrefix$baseKey');
          await _prefs!.remove(expireKey);

          // Eliminar de memoria
          _memoryCache.remove(baseKey);
        }
      }
    } catch (e) {
      print('❌ Error al limpiar caché expirada: $e');
    }
  }

  /// Recupera un valor de la caché incluso si ha expirado
  ///
  /// [key] - Clave del valor a recuperar
  /// Retorna null si la clave no existe, pero devuelve el valor aunque esté expirado
  Future<T?> getExpired<T>(String key) async {
    if (!_isInitialized()) {
      await init();
    }

    try {
      // Verificar si hay valor en memoria
      if (_memoryCache.containsKey(key)) {
        final value = _memoryCache[key];
        if (value is T) {
          return value;
        }
      }

      // Recuperar de persistencia, ignorando expiración
      final data = _prefs!.getString('$_cacheKeyPrefix$key');
      if (data == null) {
        return null;
      }

      // Decodificar datos
      final cacheData = json.decode(data);
      final valueString = cacheData['value'];
      final type = cacheData['type'];

      // Deserializar según el tipo (mismo código que en get)
      dynamic deserializedValue;

      if (type == 'UserModel' && T == UserModel) {
        deserializedValue = UserModel.fromJson(json.decode(valueString));
      } else if (type == 'MatchModel' && T == MatchModel) {
        final matchData = json.decode(valueString);
        deserializedValue =
            MatchModel.fromMap(matchData, matchData['id'] ?? '');
      } else if (type == 'List<MatchModel>') {
        final listData = json.decode(valueString) as List;
        deserializedValue = listData.map((matchData) {
          return MatchModel.fromMap(matchData, matchData['id'] ?? '');
        }).toList();
      } else if (type == 'List') {
        deserializedValue = json.decode(valueString);
      } else if (type == 'String' ||
          type == 'int' ||
          type == 'double' ||
          type == 'bool') {
        if (type == 'int') {
          deserializedValue = int.tryParse(valueString) ?? 0;
        } else if (type == 'double') {
          deserializedValue = double.tryParse(valueString) ?? 0.0;
        } else if (type == 'bool') {
          deserializedValue = valueString.toLowerCase() == 'true';
        } else {
          deserializedValue = valueString;
        }
      } else {
        deserializedValue = json.decode(valueString);
      }

      // Actualizar caché en memoria
      _memoryCache[key] = deserializedValue;

      if (deserializedValue is T) {
        return deserializedValue as T;
      }

      return null;
    } catch (e) {
      print('❌ Error al recuperar de caché expirada: $e');
      return null;
    }
  }

  /// Verifica si un valor es de tipo básico
  bool _isBasicType(dynamic value) {
    return value == null || value is num || value is bool || value is String;
  }

  /// Verifica si una clave existe en la caché y no ha expirado
  Future<bool> exists(String key) async {
    if (!_isInitialized()) {
      await init();
    }

    try {
      // Verificar si hay valor en memoria
      if (_memoryCache.containsKey(key)) {
        return true;
      }

      // Verificar si ha expirado
      final expireTime = _prefs!.getInt('$_expireKeyPrefix$key');
      if (expireTime == null ||
          expireTime < DateTime.now().millisecondsSinceEpoch) {
        // Caché expirada o inexistente
        return false;
      }

      // Verificar si existe el valor en persistencia
      return _prefs!.containsKey('$_cacheKeyPrefix$key');
    } catch (e) {
      print('❌ Error al verificar existencia en caché: $e');
      return false;
    }
  }

  /// Obtiene información de depuración sobre el caché
  Future<Map<String, dynamic>> getDebugInfo() async {
    if (!_isInitialized()) {
      await init();
    }

    try {
      final cacheKeys = _prefs!
          .getKeys()
          .where((key) => key.startsWith(_cacheKeyPrefix))
          .toList();

      final expireKeys = _prefs!
          .getKeys()
          .where((key) => key.startsWith(_expireKeyPrefix))
          .toList();

      return {
        'totalCacheEntries': cacheKeys.length,
        'totalExpireEntries': expireKeys.length,
        'memoryEntries': _memoryCache.length,
        'cacheKeys':
            cacheKeys.map((k) => k.substring(_cacheKeyPrefix.length)).toList(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
