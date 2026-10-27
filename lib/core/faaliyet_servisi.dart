import 'package:flutter/material.dart';
import 'constants.dart';
import 'ortak.dart';

class FaaliyetServisi {
  static Future<bool> kaydet(BuildContext context,
      {Map<String, dynamic>? mevcut,
      required Map<String, dynamic> veri}) async {
    try {
      if (mevcut == null) {
        await supabase.from('faaliyetler').insert(veri);

        // EĞER ONAYLIYSA VE KİŞİ ATANMIŞSA ANINDA BİLDİRİM GÖNDER
        if (veri['onay_durumu'] != 'Bekliyor' &&
            veri['atanan_kisi_id'] != null) {
          await supabase.functions.invoke(
            'gorev-bildirimi',
            body: {
              'hedefKullaniciId': veri['atanan_kisi_id'],
              'faaliyetBaslik': veri['baslik'],
              'tarih': veri['tarih'],
              'birim': veri['hedef_birim'] ?? 'Genel',
              'baslik': '📢 Yeni Bir Görev Atandı!'
            },
          );
        }
      } else {
        await supabase.from('faaliyetler').update(veri).eq('id', mevcut['id']);

        // GÖREV BAŞKA BİRİNE DEVREDİLDİYSE VEYA YENİ ONAYLANDIYSA BİLDİRİM GÖNDER
        if (veri['onay_durumu'] != 'Bekliyor' &&
            veri['atanan_kisi_id'] != null &&
            mevcut['atanan_kisi_id'] != veri['atanan_kisi_id']) {
          await supabase.functions.invoke(
            'gorev-bildirimi',
            body: {
              'hedefKullaniciId': veri['atanan_kisi_id'],
              'faaliyetBaslik': veri['baslik'],
              'tarih': veri['tarih'],
              'birim': veri['hedef_birim'] ?? 'Genel',
              'baslik': '🔄 Görev Size Devredildi / Onaylandı'
            },
          );
        }
      }
      return true;
    } catch (e) {
      debugPrint('Kaydetme hatası: $e');
      if (context.mounted)
        bildir(context, 'İşlem başarısız: $e', renk: Colors.red);
      return false;
    }
  }

  static Future<void> sil(BuildContext context, Map<String, dynamic> f) async {
    final onay = await onayDialogu(context,
        baslik: 'Faaliyeti Sil',
        mesaj: '"${f['baslik']}" silinecek. Onaylıyor musunuz?');
    if (!onay) return;
    try {
      await supabase.from('faaliyetler').delete().eq('id', f['id']);
      if (context.mounted) bildir(context, 'Faaliyet başarıyla silindi.');
    } catch (e) {
      debugPrint('Faaliyet silinemedi: $e');
      if (context.mounted) bildir(context, 'Silinemedi.', renk: Colors.red);
    }
  }

  static Future<void> durumGuncelle(
      BuildContext context, Map<String, dynamic> f, String yeniDurum) async {
    try {
      await supabase
          .from('faaliyetler')
          .update({'durum': yeniDurum}).eq('id', f['id']);
      if (context.mounted) bildir(context, 'Durum başarıyla güncellendi.');
    } catch (e) {
      debugPrint('Durum güncellenemedi: $e');
      if (context.mounted) bildir(context, 'Güncellenemedi.', renk: Colors.red);
    }
  }
}
