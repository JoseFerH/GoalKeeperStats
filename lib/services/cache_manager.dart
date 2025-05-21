import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Administrador de caché para almacenar y recuperar datos localmente
///
/// Permite guardar objetos en caché con tiempo de expiración para mejorar
/// el rendimiento y proporcionar funcionalidad sin conexión.
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  late SharedPreferences _prefs;
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
    _prefs = await SharedPreferences.getInstance();
    _cleanExpiredCache();
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
      final expireTime = DateTime.now().add(Duration(seconds: duration)).millisecondsSinceEpoch;
      
      // Almacenar en memoria para acceso rápido
      _memoryCache[key] = value;
      
      // Convertir valor a JSON
      final jsonValue = _isBasicType(value) 
          ? value 
          : json.encode(value);
      
      // Guardar en persistencia con información de tipo
      final cacheData = {
        'value': jsonValue,
        'type': T.toString(),
      };
      
      // Guardar datos y tiempo de expiración
      await _prefs.setString('$_cacheKeyPrefix$key', json.encode(cacheData));
      await _prefs.setInt('$_expireKeyPrefix$key', expireTime);
      
      return true;
    } catch (e) {
      print('Error al guardar en caché: $e');
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
      final expireTime = _prefs.getInt('$_expireKeyPrefix$key');
      if (expireTime == null || expireTime < DateTime.now().millisecondsSinceEpoch) {
        // Caché expirada o inexistente
        return null;
      }
      
      // Recuperar de persistencia
      final data = _prefs.getString('$_cacheKeyPrefix$key');
      if (data == null) {
        return null;
      }
      
      // Decodificar datos
      final cacheData = json.decode(data);
      final value = cacheData['value'];
      final type = cacheData['type'];
      
      // Convertir según el tipo
      if (_isBasicType(value)) {
        // Actualizar caché en memoria
        _memoryCache[key] = value;
        return value as T;
      } else if (value is String) {
        // Deserializar objetos JSON
        final decodedValue = _deserializeValue<T>(value);
        // Actualizar caché en memoria
        _memoryCache[key] = decodedValue;
        return decodedValue;
      }
      
      return null;
    } catch (e) {
      print('Error al recuperar de caché: $e');
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
      await _prefs.remove('$_cacheKeyPrefix$key');
      await _prefs.remove('$_expireKeyPrefix$key');
      
      return true;
    } catch (e) {
      print('Error al eliminar de caché: $e');
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
      final keys = _prefs.getKeys()
          .where((key) => key.startsWith(_cacheKeyPrefix) || 
                          key.startsWith(_expireKeyPrefix))
          .toList();
      
      // Eliminar todas las claves
      for (final key in keys) {
        await _prefs.remove(key);
      }
      
      return true;
    } catch (e) {
      print('Error al limpiar caché: $e');
      return false;
    }
  }
  
  /// Verifica si el administrador de caché está inicializado
  bool _isInitialized() {
    try {
      return _prefs != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Limpia entradas de caché expiradas
  Future<void> _cleanExpiredCache() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    try {
      // Obtener todas las claves de expiración
      final expireKeys = _prefs.getKeys()
          .where((key) => key.startsWith(_expireKeyPrefix))
          .toList();
      
      // Verificar cada clave
      for (final expireKey in expireKeys) {
        final expireTime = _prefs.getInt(expireKey);
        
        if (expireTime != null && expireTime < now) {
          // Extraer la clave base
          final baseKey = expireKey.substring(_expireKeyPrefix.length);
          
          // Eliminar clave expirada
          await _prefs.remove('$_cacheKeyPrefix$baseKey');
          await _prefs.remove(expireKey);
          
          // Eliminar de memoria
          _memoryCache.remove(baseKey);
        }
      }
    } catch (e) {
      print('Error al limpiar caché expirada: $e');
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
    final data = _prefs.getString('$_cacheKeyPrefix$key');
    if (data == null) {
      return null;
    }
    
    // Decodificar datos
    final cacheData = json.decode(data);
    final value = cacheData['value'];
    
    // Convertir según el tipo
    if (_isBasicType(value)) {
      // Actualizar caché en memoria
      _memoryCache[key] = value;
      return value as T;
    } else if (value is String) {
      // Deserializar objetos JSON
      final decodedValue = _deserializeValue<T>(value);
      // Actualizar caché en memoria
      _memoryCache[key] = decodedValue;
      return decodedValue;
    }
    
    return null;
  } catch (e) {
    print('Error al recuperar de caché expirada: $e');
    return null;
  }
}
  /// Verifica si un valor es de tipo básico
  bool _isBasicType(dynamic value) {
    return value == null || 
           value is num || 
           value is bool || 
           value is String;
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
    final expireTime = _prefs.getInt('$_expireKeyPrefix$key');
    if (expireTime == null || expireTime < DateTime.now().millisecondsSinceEpoch) {
      // Caché expirada o inexistente
      return false;
    }
    
    // Verificar si existe el valor en persistencia
    return _prefs.containsKey('$_cacheKeyPrefix$key');
  } catch (e) {
    print('Error al verificar existencia en caché: $e');
    return false;
  }
}
  /// Deserializa un valor según su tipo
  T? _deserializeValue<T>(String jsonValue) {
    try {
      final decoded = json.decode(jsonValue);
      
      if ((T == List<dynamic> )|| T.toString().startsWith('List<')) {
        if (decoded is List) {
          return decoded as T;
        }
      } else if ((T == Map<String, dynamic> )|| T.toString().startsWith('Map<')) {
        if (decoded is Map) {
          return decoded as T;
        }
      }
      
      return decoded as T;
    } catch (e) {
      print('Error al deserializar valor: $e');
      return null;
    }
  }
}