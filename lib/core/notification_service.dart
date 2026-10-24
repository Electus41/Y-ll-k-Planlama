import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'constants.dart';

class NotificationService {
  static bool get _aktifMi =>
      !kIsWeb &&
      OneSignalConfig.appId.isNotEmpty &&
      !OneSignalConfig.appId.contains('BURAYA');

  /// Uygulama açılışında OneSignal'ı başlatır
  static Future<void> baslat() async {
    if (!_aktifMi) return;
    try {
      OneSignal.initialize(OneSignalConfig.appId);
      await OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      debugPrint('OneSignal başlatma uyarısı: $e');
    }
  }

  /// Giriş yapan kullanıcının bilgilerini ve telefon bildirim ID'sini profiller tablosuna kaydeder
  static Future<void> kullaniciCihaziniSenkronizeEt() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    String? subId;
    if (_aktifMi) {
      try {
        await OneSignal.login(user.id);
        subId = OneSignal.User.pushSubscription.id;
      } catch (e) {
        debugPrint('OneSignal ID alınamadı: $e');
      }
    }

    final meta = user.userMetadata ?? {};

    try {
      final mevcut = await supabase
          .from('profiller')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final Map<String, dynamic> veri = {
        'id': user.id,
        'ad': mevcut?['ad'] ?? meta['ad'] ?? '',
        'soyad': mevcut?['soyad'] ?? meta['soyad'] ?? '',
        'telefon': mevcut?['telefon'] ?? meta['telefon'] ?? '',
        'unvan': mevcut?['unvan'] ?? meta['unvan'] ?? 'Yönetici',
        'email': user.email ?? '',
      };

      if (subId != null && subId.isNotEmpty) {
        veri['onesignal_id'] = subId;
      }

      await supabase.from('profiller').upsert(veri);
    } catch (e) {
      debugPrint('Profil senkronizasyon uyarısı: $e');
    }
  }

  /// Görev atanan kişiye (Uygulama kapalı olsa bile) anlık Push Bildirim gönderir
  static Future<void> gorevBildirimiGonder({
    required String hedefKullaniciId,
    required String faaliyetBaslik,
    required String tarih,
    required String birim,
  }) async {
    if (OneSignalConfig.restApiKey.contains('BURAYA') ||
        OneSignalConfig.appId.contains('BURAYA')) {
      debugPrint(
          'OneSignal anahtarları henüz girilmediği için bildirim atlandı.');
      return;
    }

    try {
      final profil = await supabase
          .from('profiller')
          .select('onesignal_id')
          .eq('id', hedefKullaniciId)
          .maybeSingle();

      final String? onesignalId = profil?['onesignal_id'];

      final Map<String, dynamic> govde = {
        'app_id': OneSignalConfig.appId,
        'headings': {
          'tr': '📌 Yeni Görev Atandı!',
          'en': '📌 Yeni Görev Atandı!'
        },
        'contents': {
          'tr': '$faaliyetBaslik ($birim) - Tarih: $tarih',
          'en': '$faaliyetBaslik ($birim) - Tarih: $tarih',
        },
      };

      if (onesignalId != null && onesignalId.isNotEmpty) {
        govde['include_subscription_ids'] = [onesignalId];
      } else {
        govde['include_aliases'] = {
          'external_id': [hedefKullaniciId]
        };
        govde['target_channel'] = 'push';
      }

      await http.post(
        Uri.parse('https://api.onesignal.com/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key ${OneSignalConfig.restApiKey}',
        },
        body: jsonEncode(govde),
      );
    } catch (e) {
      debugPrint('Bildirim gönderme hatası: $e');
    }
  }
}
