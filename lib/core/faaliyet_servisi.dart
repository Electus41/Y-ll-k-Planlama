import 'package:flutter/material.dart';
import 'constants.dart';
import 'notification_service.dart';
import 'ortak.dart';

/// Faaliyet ekle / güncelle / sil / durum değiştir işlemleri tek yerde.
/// Bildirim kuralı: yeni kayıtta veya atanan kişi değiştiğinde gider.
class FaaliyetServisi {
  static Future<bool> kaydet(BuildContext context,
      {Map<String, dynamic>? mevcut,
      required Map<String, dynamic> veri}) async {
    try {
      if (mevcut != null) {
        final s = await supabase
            .from('faaliyetler')
            .update(veri)
            .eq('id', mevcut['id'])
            .select();
        if (s.isEmpty) {
          if (context.mounted) {
            bildir(context, 'Bu kaydı değiştirme yetkiniz yok.',
                renk: Colors.orange);
          }
          return false;
        }
      } else {
        await supabase.from('faaliyetler').insert(veri);
      }
    } catch (e) {
      debugPrint('Faaliyet kaydedilemedi: $e');
      if (context.mounted) {
        bildir(context,
            'Kaydedilemedi. Yetkiniz olmayabilir veya bağlantı sorunu var.',
            renk: Colors.red);
      }
      return false;
    }

    final yeni = veri['atanan_kisi_id']?.toString();
    final eski = mevcut?['atanan_kisi_id']?.toString();
    if (yeni != null && yeni != eski) {
      final hata = await NotificationService.gorevBildirimiGonder(
        hedefKullaniciId: yeni,
        faaliyetBaslik: veri['baslik'].toString(),
        tarih: veri['tarih'].toString(),
        birim: mevcut == null ? 'Yeni Görev' : 'Görev Size Atandı',
      );
      if (hata != null && context.mounted) {
        bildir(context, 'Kaydedildi ama bildirim gönderilemedi: $hata',
            renk: Colors.orange);
      }
    }
    return true;
  }

  static Future<bool> sil(BuildContext context, Map<String, dynamic> f) async {
    final onay = await onayDialogu(context,
        baslik: 'Silmek İstediğinize Emin Misiniz?',
        mesaj: '"${f['baslik']}" kalıcı olarak silinecek.');
    if (!onay) return false;
    try {
      final s = await supabase
          .from('faaliyetler')
          .delete()
          .eq('id', f['id'])
          .select();
      if (s.isEmpty) {
        if (context.mounted) {
          bildir(context, 'Bu kaydı silme yetkiniz yok.', renk: Colors.orange);
        }
        return false;
      }
      if (context.mounted)
        bildir(context, 'Faaliyet silindi.', renk: Colors.red);
      return true;
    } catch (e) {
      debugPrint('Faaliyet silinemedi: $e');
      if (context.mounted) {
        bildir(context, 'Silinemedi. Lütfen tekrar deneyin.', renk: Colors.red);
      }
      return false;
    }
  }

  static Future<bool> durumGuncelle(
      BuildContext context, Map<String, dynamic> f, String yeniDurum) async {
    try {
      final s = await supabase
          .from('faaliyetler')
          .update({'durum': yeniDurum})
          .eq('id', f['id'])
          .select();
      if (s.isEmpty) {
        if (context.mounted) {
          bildir(context, 'Bu görevin durumunu değiştirme yetkiniz yok.',
              renk: Colors.orange);
        }
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Durum güncellenemedi: $e');
      if (context.mounted) {
        bildir(context, 'Durum güncellenemedi.', renk: Colors.red);
      }
      return false;
    }
  }
}
