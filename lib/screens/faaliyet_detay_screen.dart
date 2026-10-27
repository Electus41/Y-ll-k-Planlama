import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/faaliyet_servisi.dart';
import '../core/notification_service.dart';
import '../core/ortak.dart';
import '../widgets/faaliyet_form_dialog.dart';

List<Map<String, dynamic>> _liste(dynamic v) => v is List
    ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList()
    : <Map<String, dynamic>>[];

class FaaliyetDetayScreen extends StatefulWidget {
  final String faaliyetId;
  const FaaliyetDetayScreen({super.key, required this.faaliyetId});

  @override
  State<FaaliyetDetayScreen> createState() => _FaaliyetDetayScreenState();
}

class _FaaliyetDetayScreenState extends State<FaaliyetDetayScreen> {
  late final Stream<List<Map<String, dynamic>>> _stream;
  Yetki? _yetki;

  @override
  void initState() {
    super.initState();
    _stream = supabase
        .from('faaliyetler')
        .stream(primaryKey: ['id']).eq('id', widget.faaliyetId);
    Yetki.yukle().then((y) {
      if (mounted) setState(() => _yetki = y);
    });
  }

  Future<bool> _guncelle(Map<String, dynamic> alanlar) async {
    try {
      final s = await supabase
          .from('faaliyetler')
          .update(alanlar)
          .eq('id', widget.faaliyetId)
          .select();
      if (s.isEmpty) {
        if (mounted) {
          bildir(context, 'Bu kaydı değiştirme yetkiniz yok.',
              renk: Colors.orange);
        }
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Detay güncellenemedi: $e');
      if (mounted) bildir(context, 'Kaydedilemedi.', renk: Colors.red);
      return false;
    }
  }

  // ---------- Konum ----------
  Future<void> _haritadaAc(Map<String, dynamic> f) async {
    final ad = (f['konum_adi'] ?? '').toString().trim();
    final adres = (f['konum_adres'] ?? '').toString().trim();
    Uri uri;
    if (adres.startsWith('http')) {
      uri = Uri.parse(adres);
    } else {
      final q = [ad, adres].where((e) => e.isNotEmpty).join(' ');
      uri = Uri.https(
          'www.google.com', '/maps/search/', {'api': '1', 'query': q});
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        bildir(context, 'Harita açılamadı.', renk: Colors.orange);
      }
    } catch (e) {
      debugPrint('Harita hatası: $e');
      if (mounted) bildir(context, 'Harita açılamadı.', renk: Colors.orange);
    }
  }

  Future<void> _konumDuzenle(Map<String, dynamic> f) async {
    final adCtrl =
        TextEditingController(text: f['konum_adi']?.toString() ?? '');
    final adresCtrl =
        TextEditingController(text: f['konum_adres']?.toString() ?? '');
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kutuRengi,
        title: const Text('Konum', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: adCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: koyuInput(
                    label: 'Konum Adı (örn. Gebze Spor Salonu)',
                    icon: Icons.place)),
            const SizedBox(height: 12),
            TextField(
                controller: adresCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: koyuInput(
                    label: 'Adres veya Google Haritalar linki (opsiyonel)',
                    icon: Icons.map)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('İptal', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (kaydet == true) {
      await _guncelle({
        'konum_adi': adCtrl.text.trim(),
        'konum_adres': adresCtrl.text.trim(),
      });
    }
  }

  // ---------- Misafirler ----------
  Future<void> _misafirEkle(Map<String, dynamic> f) async {
    final adCtrl = TextEditingController();
    final kurumCtrl = TextEditingController();
    final notCtrl = TextEditingController();
    final ekle = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kutuRengi,
        title:
            const Text('Misafir Ekle', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: adCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: koyuInput(label: 'Ad Soyad', icon: Icons.person)),
            const SizedBox(height: 12),
            TextField(
                controller: kurumCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: koyuInput(
                    label: 'Unvan / Kurum (opsiyonel)', icon: Icons.business)),
            const SizedBox(height: 12),
            TextField(
                controller: notCtrl,
                style: const TextStyle(color: Colors.white),
                decoration:
                    koyuInput(label: 'Not (opsiyonel)', icon: Icons.notes)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('İptal', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ekle')),
        ],
      ),
    );
    if (ekle == true && adCtrl.text.trim().isNotEmpty) {
      final liste = _liste(f['misafirler']);
      liste.add({
        'ad': adCtrl.text.trim(),
        'kurum': kurumCtrl.text.trim(),
        'not': notCtrl.text.trim(),
      });
      await _guncelle({'misafirler': liste});
    }
  }

  Future<void> _misafirSil(Map<String, dynamic> f, int index) async {
    final liste = _liste(f['misafirler']);
    if (index < 0 || index >= liste.length) return;
    final onay = await onayDialogu(context,
        baslik: 'Misafiri Sil',
        mesaj: '${liste[index]['ad']} listeden çıkarılsın mı?');
    if (!onay) return;
    liste.removeAt(index);
    await _guncelle({'misafirler': liste});
  }

  // ---------- Katılımcılar ----------
  Future<void> _katilimciSec(Map<String, dynamic> f) async {
    List<Map<String, dynamic>> kisiler;
    try {
      kisiler = List<Map<String, dynamic>>.from(await supabase
          .from('profiller')
          .select('id, ad, soyad, unvan')
          .order('ad'));
    } catch (e) {
      debugPrint('Kişi listesi alınamadı: $e');
      if (mounted) bildir(context, 'Kişi listesi alınamadı.', renk: Colors.red);
      return;
    }
    if (!mounted) return;
    final mevcutIdler =
        _liste(f['katilimcilar']).map((k) => k['id'].toString()).toSet();
    final secili = <String>{...mevcutIdler};

    final tamam = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          backgroundColor: kutuRengi,
          title: const Text('Katılımcıları Seç',
              style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView(
              children: kisiler.map((k) {
                final id = k['id'].toString();
                return CheckboxListTile(
                  dense: true,
                  activeColor: AppColors.accent,
                  checkColor: Colors.black,
                  value: secili.contains(id),
                  title: Text(kisiEtiketi(k),
                      style: const TextStyle(color: Colors.white)),
                  onChanged: (v) => setM(
                      () => v == true ? secili.add(id) : secili.remove(id)),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal',
                    style: TextStyle(color: Colors.white54))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (tamam != true) return;

    final yeniListe = kisiler
        .where((k) => secili.contains(k['id'].toString()))
        .map((k) => {'id': k['id'].toString(), 'ad': tamAdGetir(k)})
        .toList();
    final ok = await _guncelle({'katilimcilar': yeniListe});
    if (!ok) return;

    // Yeni eklenenlere bildirim
    final yeniler = secili.difference(mevcutIdler);
    String? sonHata;
    for (final id in yeniler) {
      final h = await NotificationService.gorevBildirimiGonder(
        hedefKullaniciId: id,
        faaliyetBaslik: f['baslik'].toString(),
        tarih: tarihGoster(f['tarih']?.toString()),
        birim: 'Katılımcı olarak eklendiniz',
        baslik: '📅 Etkinliğe Katılımcı Eklendiniz',
      );
      if (h != null) sonHata = h;
    }
    if (sonHata != null && mounted) {
      bildir(context, 'Bazı bildirimler gönderilemedi: $sonHata',
          renk: Colors.orange);
    }
  }

  // ---------- Arayüz ----------
  Widget _kart(
      {required String baslik,
      required IconData ikon,
      required Widget icerik,
      Widget? aksiyon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(ikon, color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(baslik,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15))),
            if (aksiyon != null) aksiyon,
          ]),
          const SizedBox(height: 10),
          icerik,
        ],
      ),
    );
  }

  Widget _bilgi(String etiket, String deger) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(etiket,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13))),
            Expanded(
                child: Text(deger,
                    style: const TextStyle(color: Colors.white, fontSize: 13))),
          ],
        ),
      );

  Widget _iskelet(Widget body,
      {String baslik = 'Faaliyet Detayı', List<Widget>? actions}) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(baslik,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: actions,
      ),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _iskelet(const Center(
              child: Text('Veri alınamadı.',
                  style: TextStyle(color: Colors.redAccent))));
        }
        if (!snap.hasData) {
          return _iskelet(const Center(
              child: CircularProgressIndicator(color: AppColors.accent)));
        }
        if (snap.data!.isEmpty) {
          return _iskelet(const Center(
              child: Text('Bu faaliyet bulunamadı veya silindi.',
                  style: TextStyle(color: Colors.white54))));
        }

        final f = snap.data!.first;
        final yonet = _yetki?.yonetebilir(f) ?? false;
        final durumDegisir = _yetki?.durumDegistirebilir(f) ?? false;
        final renk = durumRengi(f['durum']?.toString());
        final konumAdi = (f['konum_adi'] ?? '').toString();
        final konumAdres = (f['konum_adres'] ?? '').toString();
        final misafirler = _liste(f['misafirler']);
        final katilimcilar = _liste(f['katilimcilar']);
        final kisi = (f['sorumlu_kisi_ad'] ?? '').toString();

        Widget durumChip = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: renk.withValues(alpha: 0.5))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(f['durum']?.toString() ?? 'Yapılacak',
                style: TextStyle(
                    color: renk, fontWeight: FontWeight.bold, fontSize: 12)),
            if (durumDegisir) ...[
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: renk, size: 18),
            ],
          ]),
        );
        if (durumDegisir) {
          durumChip = PopupMenuButton<String>(
            color: AppColors.inputFill,
            onSelected: (v) => FaaliyetServisi.durumGuncelle(context, f, v),
            itemBuilder: (_) => durumlar
                .where((d) => d != f['durum'])
                .map((d) => PopupMenuItem(
                    value: d,
                    child:
                        Text(d, style: const TextStyle(color: Colors.white))))
                .toList(),
            child: durumChip,
          );
        }

        return _iskelet(
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _kart(
                baslik: f['baslik']?.toString() ?? '',
                ikon: Icons.event,
                aksiyon: durumChip,
                icerik: Column(children: [
                  _bilgi('Tarih', tarihGoster(f['tarih']?.toString())),
                  _bilgi('Sorumlu Birim',
                      f['olusturan_unvan']?.toString() ?? 'Belirtilmedi'),
                  if (kisi.isNotEmpty) _bilgi('Sorumlu Kişi', kisi),
                  _bilgi('Hedef Komisyon',
                      f['hedef_birim']?.toString() ?? 'Genel'),
                  _bilgi('Öncelik', f['oncelik']?.toString() ?? 'Normal'),
                  _bilgi('Atayan', f['atayan_ad']?.toString() ?? '-'),
                ]),
              ),
              _kart(
                baslik: 'Konum',
                ikon: Icons.place,
                aksiyon: yonet
                    ? IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit,
                            size: 20, color: Colors.blueAccent),
                        onPressed: () => _konumDuzenle(f))
                    : null,
                icerik: (konumAdi.isEmpty && konumAdres.isEmpty)
                    ? const Text('Konum girilmemiş.',
                        style: TextStyle(color: Colors.white54))
                    : InkWell(
                        onTap: () => _haritadaAc(f),
                        child: Row(children: [
                          const Icon(Icons.map, color: Colors.lightBlueAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (konumAdi.isNotEmpty)
                                  Text(konumAdi,
                                      style: const TextStyle(
                                          color: Colors.lightBlueAccent,
                                          fontWeight: FontWeight.bold,
                                          decoration:
                                              TextDecoration.underline)),
                                if (konumAdres.isNotEmpty &&
                                    !konumAdres.startsWith('http'))
                                  Text(konumAdres,
                                      style: const TextStyle(
                                          color: Colors.white60, fontSize: 12)),
                                const Text('Haritalarda açmak için dokunun',
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                          ),
                        ]),
                      ),
              ),
              _kart(
                baslik: 'Misafirler (${misafirler.length})',
                ikon: Icons.star,
                aksiyon: yonet
                    ? IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_circle,
                            color: AppColors.accent),
                        onPressed: () => _misafirEkle(f))
                    : null,
                icerik: misafirler.isEmpty
                    ? const Text('Misafir eklenmemiş.',
                        style: TextStyle(color: Colors.white54))
                    : Column(
                        children: List.generate(misafirler.length, (i) {
                          final m = misafirler[i];
                          final alt = [
                            (m['kurum'] ?? '').toString(),
                            (m['not'] ?? '').toString()
                          ].where((e) => e.isNotEmpty).join(' • ');
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(m['ad']?.toString() ?? '',
                                style: const TextStyle(color: Colors.white)),
                            subtitle: alt.isEmpty
                                ? null
                                : Text(alt,
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12)),
                            trailing: yonet
                                ? IconButton(
                                    icon: const Icon(Icons.delete,
                                        size: 20, color: Colors.redAccent),
                                    onPressed: () => _misafirSil(f, i))
                                : null,
                          );
                        }),
                      ),
              ),
              _kart(
                baslik: 'Katılımcılar (${katilimcilar.length})',
                ikon: Icons.groups,
                aksiyon: yonet
                    ? IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit,
                            size: 20, color: Colors.blueAccent),
                        onPressed: () => _katilimciSec(f))
                    : null,
                icerik: katilimcilar.isEmpty
                    ? const Text('Katılımcı seçilmemiş.',
                        style: TextStyle(color: Colors.white54))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: katilimcilar
                            .map((k) => Chip(
                                  backgroundColor: AppColors.inputFill,
                                  label: Text(k['ad']?.toString() ?? '',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ))
                            .toList(),
                      ),
              ),
              if (yonet) _ButceBolumu(faaliyetId: f['id'].toString()),
            ],
          ),
          actions: yonet
              ? [
                  IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Düzenle',
                      onPressed: () => faaliyetFormuAc(context, mevcut: f)),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      tooltip: 'Sil',
                      onPressed: () => FaaliyetServisi.sil(context, f)),
                ]
              : null,
        );
      },
    );
  }
}

// =================== BÜTÇE ===================
class _ButceBolumu extends StatefulWidget {
  final String faaliyetId;
  const _ButceBolumu({required this.faaliyetId});

  @override
  State<_ButceBolumu> createState() => _ButceBolumuState();
}

class _ButceBolumuState extends State<_ButceBolumu> {
  late final Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = supabase
        .from('faaliyet_butce_kalemleri')
        .stream(primaryKey: ['id'])
        .eq('faaliyet_id', widget.faaliyetId)
        .order('created_at');
  }

  Future<void> _kalemDialog({Map<String, dynamic>? mevcut}) async {
    final kalemCtrl =
        TextEditingController(text: mevcut?['kalem']?.toString() ?? '');
    final adetCtrl = TextEditingController(text: '${mevcut?['adet'] ?? 1}');
    final tahminiCtrl = TextEditingController(
        text: mevcut == null ? '' : '${sayi(mevcut['tahmini_tutar'])}');
    final gercekCtrl = TextEditingController(
        text: mevcut == null ? '' : '${sayi(mevcut['gerceklesen_tutar'])}');
    bool alindi = mevcut?['alindi'] == true;

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          backgroundColor: kutuRengi,
          title: Text(mevcut == null ? 'Bütçe Kalemi Ekle' : 'Kalemi Düzenle',
              style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: kalemCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: koyuInput(
                      label: 'Kalem (örn. Otobüs kiralama)',
                      icon: Icons.shopping_cart)),
              const SizedBox(height: 12),
              TextField(
                  controller: adetCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: koyuInput(label: 'Adet', icon: Icons.numbers)),
              const SizedBox(height: 12),
              TextField(
                  controller: tahminiCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: koyuInput(
                      label: 'Tahmini Toplam Tutar (₺)',
                      icon: Icons.request_quote)),
              const SizedBox(height: 12),
              TextField(
                  controller: gercekCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: koyuInput(
                      label: 'Gerçekleşen Tutar (₺)', icon: Icons.payments)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.accent,
                title: const Text('Alındı / Ödendi',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                value: alindi,
                onChanged: (v) => setM(() => alindi = v),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal',
                    style: TextStyle(color: Colors.white54))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (kaydet != true || kalemCtrl.text.trim().isEmpty) return;

    final veri = {
      'kalem': kalemCtrl.text.trim(),
      'adet': int.tryParse(adetCtrl.text.trim()) ?? 1,
      'tahmini_tutar': sayi(tahminiCtrl.text),
      'gerceklesen_tutar': sayi(gercekCtrl.text),
      'alindi': alindi,
    };
    try {
      if (mevcut == null) {
        await supabase
            .from('faaliyet_butce_kalemleri')
            .insert({...veri, 'faaliyet_id': widget.faaliyetId});
      } else {
        await supabase
            .from('faaliyet_butce_kalemleri')
            .update(veri)
            .eq('id', mevcut['id']);
      }
    } catch (e) {
      debugPrint('Bütçe kalemi kaydedilemedi: $e');
      if (mounted) {
        bildir(context, 'Kalem kaydedilemedi. Yetkiniz olmayabilir.',
            renk: Colors.red);
      }
    }
  }

  Future<void> _alindiDegistir(Map<String, dynamic> k, bool v) async {
    try {
      await supabase
          .from('faaliyet_butce_kalemleri')
          .update({'alindi': v}).eq('id', k['id']);
    } catch (e) {
      debugPrint('Alındı güncellenemedi: $e');
      if (mounted) bildir(context, 'Güncellenemedi.', renk: Colors.red);
    }
  }

  Future<void> _kalemSil(Map<String, dynamic> k) async {
    final onay = await onayDialogu(context,
        baslik: 'Kalemi Sil', mesaj: '"${k['kalem']}" silinsin mi?');
    if (!onay) return;
    try {
      await supabase
          .from('faaliyet_butce_kalemleri')
          .delete()
          .eq('id', k['id']);
    } catch (e) {
      debugPrint('Kalem silinemedi: $e');
      if (mounted) bildir(context, 'Silinemedi.', renk: Colors.red);
    }
  }

  Widget _toplam(String baslik, String deger, Color renk) => Expanded(
        child: Column(children: [
          Text(deger,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: renk, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(baslik,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      );

  Widget _kalemSatiri(Map<String, dynamic> k) {
    final alindi = k['alindi'] == true;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: alindi,
        activeColor: AppColors.accent,
        checkColor: Colors.black,
        side: const BorderSide(color: Colors.white54),
        onChanged: (v) => _alindiDegistir(k, v ?? false),
      ),
      title: Text('${k['kalem']} (x${k['adet']})',
          style: TextStyle(
              color: alindi ? Colors.white54 : Colors.white,
              decoration: alindi ? TextDecoration.lineThrough : null)),
      subtitle: Text(
          'Tahmini: ${para(sayi(k['tahmini_tutar']))}  •  Gerçekleşen: ${para(sayi(k['gerceklesen_tutar']))}',
          style: const TextStyle(color: Colors.white54, fontSize: 11)),
      trailing: PopupMenuButton<String>(
        color: AppColors.inputFill,
        icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
        onSelected: (v) =>
            v == 'duzenle' ? _kalemDialog(mevcut: k) : _kalemSil(k),
        itemBuilder: (_) => const [
          PopupMenuItem(
              value: 'duzenle',
              child: Text('Düzenle', style: TextStyle(color: Colors.white))),
          PopupMenuItem(
              value: 'sil',
              child: Text('Sil', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  Widget _grupBasligi(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12)),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          final kalemler = snap.data ?? <Map<String, dynamic>>[];
          final tahmini =
              kalemler.fold<double>(0, (t, k) => t + sayi(k['tahmini_tutar']));
          final gercek = kalemler.fold<double>(
              0, (t, k) => t + sayi(k['gerceklesen_tutar']));
          final alinacak = kalemler.where((k) => k['alindi'] != true).toList();
          final alinan = kalemler.where((k) => k['alindi'] == true).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.account_balance_wallet,
                    color: AppColors.accent, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('Bütçe (sadece yöneticiler görür)',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15))),
                IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_circle, color: AppColors.accent),
                    onPressed: () => _kalemDialog()),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _toplam('Tahmini', para(tahmini), Colors.lightBlueAccent),
                _toplam('Harcanan', para(gercek), Colors.orangeAccent),
                _toplam(
                    'Kalan',
                    para(tahmini - gercek),
                    tahmini - gercek >= 0
                        ? Colors.greenAccent
                        : Colors.redAccent),
              ]),
              const Divider(color: Colors.white12, height: 24),
              if (snap.hasError)
                const Text('Bütçe yüklenemedi.',
                    style: TextStyle(color: Colors.redAccent))
              else if (kalemler.isEmpty)
                const Text('Henüz kalem eklenmemiş.',
                    style: TextStyle(color: Colors.white54))
              else ...[
                if (alinacak.isNotEmpty) ...[
                  _grupBasligi('ALINACAKLAR'),
                  ...alinacak.map(_kalemSatiri),
                ],
                if (alinan.isNotEmpty) ...[
                  _grupBasligi('ALINANLAR'),
                  ...alinan.map(_kalemSatiri),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
