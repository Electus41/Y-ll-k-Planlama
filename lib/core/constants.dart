import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AppColors {
  static const Color background = Color(0xFF121816);
  static const Color secondary = Color(0xFF1B4D3E);
  static const Color card = Color(0xFF1A2220);
  static const Color inputFill = Color(0xFF1F2624);
  static const Color accent = Color(0xFF69F0AE);
}

class OneSignalConfig {
  // OneSignal panelinden alacağın bilgileri buraya yapıştıracaksın
  static const String appId = 'f54b2dab-b34d-4b84-9e1d-c54608a1dd9f';
  static const String restApiKey =
      'os_v2_app_6vfs3k5tjvfyjhq5yvdario5t7b6cpb3l2bufjmcw2roaj2545djheivx52qlzfqnlssswnuus7d2gbqgpma6vluoms5i7wya5hjdri';
}
