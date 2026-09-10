// Guarda, num só lugar, os nomes e os valores padrão das preferências que o
// usuário escolhe no app (tema, tamanho da letra, etc.), para que sejam
// sempre salvas e lidas do mesmo jeito.

class AppPreferenceKeys {
  AppPreferenceKeys._();

  static const String themeChoice = 'theme_choice';
  static const String fontSize = 'font_size';
  static const String restockEnabled = 'reabastecimento_lembrete';
  static const String alertMode = 'alert_mode';
  static const String alarmSoundEnabled = 'alarm_sound_enabled';
  static const String alarmVibrationEnabled = 'alarm_vibration_enabled';
  static const String miuiAvisoMostrado = 'miui_aviso_mostrado';
  static const String hasSeenSplash = 'has_seen_splash';
}

/// Valores padrão (fallback) usados quando a chave ainda não existe no
/// SharedPreferences — ou seja, no primeiro acesso do usuário, ou quando o
/// valor salvo veio corrompido/de um tipo inesperado.
class AppPreferenceDefaults {
  AppPreferenceDefaults._();

  static const String themeChoice = 'Default';
  // Tamanho de fonte SEMPRE começa no mínimo do slider de Ajustes (0.8 =
  // 80%) — nunca pré-ampliado.
  static const double fontSize = 0.8;
  static const bool restockEnabled = false;
  static const String alertMode = 'both';
  static const bool alarmSoundEnabled = true;
  static const bool alarmVibrationEnabled = true;
  static const bool miuiAvisoMostrado = false;
  static const bool hasSeenSplash = false;
}
