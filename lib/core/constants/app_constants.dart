/// Constantes utilizadas en toda la aplicación
///
/// Centraliza valores que pueden ser utilizados en múltiples lugares
/// para facilitar cambios globales.
class AppConstants {
  // Prevenir instanciación
  AppConstants._();

  // Nombres de colecciones en Firebase
  static const String usersCollection = 'users';
  static const String matchesCollection = 'matches';
  static const String shotsCollection = 'shots';
  static const String passesCollection = 'goalkeeper_passes';

  // Límites para la versión gratuita
  static const int freeTierDailyShotsLimit = 20;
  static const bool freeTierIncludesMatches = false;

  // Duración de suscripciones
  static const int monthlySubscriptionDays = 30;
  static const int quarterlySubscriptionDays = 90;
  static const int biannualSubscriptionDays = 180;
  static const int annualSubscriptionDays = 365;

  // Identificadores para in-app purchases
  static const String monthlySubscriptionId = 'goalkeeper_stats_monthly';
  static const String quarterlySubscriptionId = 'goalkeeper_stats_quarterly';
  static const String biannualSubscriptionId = 'goalkeeper_stats_biannual';
  static const String annualSubscriptionId = 'goalkeeper_stats_annual';

  // Valores por defecto
  static const String defaultLanguage = 'es';
  static const bool defaultDarkMode = false;
  static const bool defaultNotifications = true;

  // Configuración de la portería
  // (Valores normalizados donde 1.0 es la anchura de la portería)
  static const double goalWidth = 1.0;
  static const double goalHeight = 0.4; // Relación de aspecto real

  // Configuración del campo
  static const double fieldRatio = 1.5; // Relación largo/ancho

  // Zonas de la portería (4x3 grid)
  static const Map<String, String> goalZones = {
    'top-left': 'Superior-Izquierda',
    'top-center': 'Superior-Centro',
    'top-right': 'Superior-Derecha',
    'middle-high-left': 'Media-Alta-Izquierda',
    'middle-high-center': 'Media-Alta-Centro',
    'middle-high-right': 'Media-Alta-Derecha',
    'middle-low-left': 'Media-Baja-Izquierda',
    'middle-low-center': 'Media-Baja-Centro',
    'middle-low-right': 'Media-Baja-Derecha',
    'rolling-left': 'Raso-Izquierda',
    'rolling-center': 'Raso-Centro',
    'rolling-right': 'Raso-Derecha',
  };

  // Zonas del campo para el tirador (3x8 grid)
  static const Map<String, String> shooterZones = {
    '5-left': '5 Metros-Izquierda',
    '5-center': '5 Metros-Centro',
    '5-right': '5 Metros-Derecha',
    '10-left': '10 Metros-Izquierda',
    '10-center': '10 Metros-Centro',
    '10-right': '10 Metros-Derecha',
    '15-left': '15 Metros-Izquierda',
    '15-center': '15 Metros-Centro',
    '15-right': '15 Metros-Derecha',
    '20-left': '20 Metros-Izquierda',
    '20-center': '20 Metros-Centro',
    '20-right': '20 Metros-Derecha',
    '25-left': '25 Metros-Izquierda',
    '25-center': '25 Metros-Centro',
    '25-right': '25 Metros-Derecha',
    '30-left': '30 Metros-Izquierda',
    '30-center': '30 Metros-Centro',
    '30-right': '30 Metros-Derecha',
    '35-left': '35 Metros-Izquierda',
    '35-center': '35 Metros-Centro',
    '35-right': '35 Metros-Derecha',
    '40-left': '40 Metros-Izquierda',
    '40-center': '40 Metros-Centro',
    '40-right': '40 Metros-Derecha',
  };

  // Zonas para el portero (3x4 grid)
  static const Map<String, String> goalkeeperZones = {
    'line-left': 'Línea-Izquierda',
    'line-center': 'Línea-Centro',
    'line-right': 'Línea-Derecha',
    'area-small-left': 'Área Pequeña-Izquierda',
    'area-small-center': 'Área Pequeña-Centro',
    'area-small-right': 'Área Pequeña-Derecha',
    'front-small-left': 'Frontal Pequeña-Izquierda',
    'front-small-center': 'Frontal Pequeña-Centro',
    'front-small-right': 'Frontal Pequeña-Derecha',
    'area-big-left': 'Área Grande-Izquierda',
    'area-big-center': 'Área Grande-Centro',
    'area-big-right': 'Área Grande-Derecha',
  };

  // Traducciones para tipos de partido
  static const Map<String, String> matchTypes = {
    'official': 'Partido Oficial',
    'friendly': 'Partido Amistoso',
    'training': 'Entrenamiento',
  };

  // Traducciones para tipos de saque
  static const Map<String, String> passTypes = {
    'hand': 'Saque de mano',
    'ground': 'Saque raso',
    'volley': 'Volea',
    'goal_kick': 'Saque de puerta',
  };

  // Traducciones para resultados
  static const Map<String, String> shotResults = {
    'goal': 'Gol',
    'saved': 'Atajada',
  };

  static const Map<String, String> passResults = {
    'successful': 'Correcto',
    'failed': 'Errado',
  };

  // Traducciones para tipos de tiro
  static const Map<String, String> shotTypes = {
    'open_play': 'Tiro en jugada',
    'throw_in': 'Saque de banda',
    'free_kick': 'Tiro libre',
    'sixth_foul': 'Sexta falta',
    'penalty': 'Penalti',
    'corner': 'Tiro de esquina',
  };

  // Traducciones para tipos de gol
  static const Map<String, String> goalTypes = {
    'header': 'Cabezazo',
    'volley': 'Volea',
    'one_on_one': 'Mano a mano',
    'far_post': 'Segundo palo',
    'nutmeg': 'Entre piernas',
    'rebound': 'Rebote de portero',
    'own_goal': 'Autogol',
    'deflection': 'Desvío de trayectoria',
  };

  // Traducciones para tipos de bloqueo
  static const Map<String, String> blockTypes = {
    'block': 'Bloqueo',
    'deflection': 'Desvío',
    'barrier': 'Paso de valla',
    'foot_save': 'Ataje de balón con pie',
    'side_fall_block': 'Caída lateral con bloqueo',
    'side_fall_deflection': 'Caída lateral con desvío',
    'cross': 'Cruz',
    'clearance': 'Despeje',
    'narrow_angle': 'Achique',
  };
}
