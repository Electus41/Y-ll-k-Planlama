import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

class NotificationService {
  static bool _gozlemciEklendi = false;

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

  /// Giriş yapan kullanıcıyı OneSignal'a bağlar ve cihaz kimliğini profile yazar.
  static Future<void> kullaniciCihaziniSenkronizeEt() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    String? subId;
    if (_aktifMi) {
      try {
        await OneSignal.login(user.id);
        subId = OneSignal.User.pushSubscription.id;

        // Abonelik id'si geç oluşabilir: oluşunca profile yaz.
        if (!_gozlemciEklendi) {
          _gozlemciEklendi = true;
          OneSignal.User.pushSubscription.addObserver((state) async {
            final id = state.current.id;
            final u = supabase.auth.currentUser;
            if (id != null && id.isNotEmpty && u != null) {
              try {
                await supabase
                    .from('profiller')
                    .update({'onesignal_id': id}).eq('id', u.id);
              } catch (e) {
                debugPrint('onesignal_id yazılamadı: $e');
              }
            }
          });
        }
      } catch (e) {
        debugPrint('OneSignal ID alınamadı: $e');
      }
    }

    final meta = user.userMetadata ?? {};

    try {
      final mevcut = await supabase
          .from('profiller')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (mevcut == null) {
        await supabase.from('profiller').upsert({
          'id': user.id,
          'ad': meta['ad'] ?? '',
          'soyad': meta['soyad'] ?? '',
          'telefon': meta['telefon'] ?? '',
          'unvan': meta['unvan'],
          'bagli_birim': meta['bagli_birim'],
          'email': user.email ?? '',
          if (subId != null && subId.isNotEmpty) 'onesignal_id': subId,
        });
      } else if (subId != null && subId.isNotEmpty) {
        await supabase
            .from('profiller')
            .update({'onesignal_id': subId}).eq('id', user.id);
      }
    } catch (e) {
      debugPrint('Profil senkronizasyon uyarısı: $e');
    }
  }

  /// Görev atanan kişiye push bildirim gönderir (Supabase Edge Function üzerinden).
  /// Başarılıysa null, başarısızsa hata metni döner.
  static Future<String?> gorevBildirimiGonder({
    required String hedefKullaniciId,
    required String faaliyetBaslik,
    required String tarih,
    required String birim,
    String baslik = '📌 Yeni Görev Atandı!',
  }) async {
    try {
      final res = await supabase.functions.invoke('gorev-bildirimi', body: {
        'hedefKullaniciId': hedefKullaniciId,
        'faaliyetBaslik': faaliyetBaslik,
        'tarih': tarih,
        'birim': birim,
        'baslik': baslik,
      });
      final data = res.data;
      if (data is Map && data['hata'] != null) return data['hata'].toString();
      return null;
    } on FunctionException catch (e) {
      debugPrint('Bildirim fonksiyonu hatası (${e.status}): ${e.details}');
      final d = e.details;
      if (d is Map && d['hata'] != null) return d['hata'].toString();
      return 'Bildirim servisi hatası (${e.status})';
    } catch (e) {
      debugPrint('Bildirim gönderme hatası: $e');
      return e.toString();
    }
  }
}
