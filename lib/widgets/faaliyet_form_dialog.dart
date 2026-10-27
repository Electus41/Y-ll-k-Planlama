import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/faaliyet_servisi.dart';
import '../core/ortak.dart';

Future<bool> faaliyetFormuAc(BuildContext context,
    {Map<String, dynamic>? mevcut, String? varsayilanHedefId}) async {
  final yetki = await Yetki.yukle();
  if (!context.mounted) return false;
  if (yetki == null || yetki.gonullu) {
    bildir(context, 'Faaliyet eklemek veya düzenlemek için yetkiniz yok.',
        renk: Colors.orange);
    return false;
  }

  List<Map<String, dynamic>> kisiler = [];
  List<Map<String, dynamic>> birimler = [];
  try {
    kisiler = List<Map<String, dynamic>>.from(await supabase
        .from('profiller')
        .select('id, ad, soyad, unvan, ilce_id, onay_durumu')
        .order('ad'));
    birimler = List<Map<String, dynamic>>.from(await supabase
        .from('birimler')
        .select('id, ad, kategori, ilce_id')
        .order('sira'));
  } catch (e) {
    debugPrint('Form listeleri yüklenemedi: $e');
    if (context.mounted) {
      bildir(context, 'Kişi ve birim listeleri yüklenemedi.', renk: Colors.red);
    }
    return false;
  }
  if (!context.mounted) return false;

  final sonuc = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FaaliyetFormu(
      yetki: yetki,
      kisiler: kisiler,
      birimler: birimler,
      mevcut: mevcut,
      varsayilanHedefId: varsayilanHedefId,
    ),
  );
  return sonuc == true;
}

class _FaaliyetFormu extends StatefulWidget {
  final Yetki yetki;
  final List<Map<String, dynamic>> kisiler;
  final List<Map<String, dynamic>> birimler;
  final Map<String, dynamic>? mevcut;
  final String? varsayilanHedefId;

  const _FaaliyetFormu({
    required this.yetki,
    required this.kisiler,
    required this.birimler,
    this.mevcut,
    this.varsayilanHedefId,
  });

  @override
  State<_FaaliyetFormu> createState() => _FaaliyetFormuState();
}

class _FaaliyetFormuState extends State<_FaaliyetFormu> {
  late final TextEditingController _baslik;
  late DateTime _bas;
  late DateTime _bit;
  bool _aralik = false;
  String? _ilceId;
  String? _sorumluId, _hedefId, _kisiId;
  String _durum = 'Yapılacak';
  String _oncelik = 'Normal';
  bool _kaydediliyor = false;

  bool get _secebilir => widget.yetki.admin || widget.yetki.ilceAdmini;

  bool _ilceUygun(Map<String, dynamic> b) {
    final ad = b['ad'].toString().trim();
    final lowerAd = ad.toLowerCase();

    // 1. İlkokulu kökten gizle
    if (lowerAd.contains('ilkokul')) return false;

    // 2. Şahsi makamlar ve üst düzey yönetimleri birim listesinden çıkar
    if (lowerAd == 'il' ||
        lowerAd == 'i̇l' ||
        lowerAd.contains('gölge') ||
        lowerAd.contains('teşkilatlanma')) return false;
    if (ustUnvanlar.contains(ad)) return false;

    // 3. Üniversite sadece İl'de görünür
    if (_ilceId != null && lowerAd.contains('üniversite')) return false;

    return b['ilce_id']?.toString() == _ilceId;
  }

  List<Map<String, dynamic>> _listeTemizle(
      Iterable<Map<String, dynamic>> hamListe) {
    final zirhliListe = <String, Map<String, dynamic>>{};
    for (final b in hamListe) {
      final id = b['id']?.toString();
      String ad = b['ad']?.toString().trim() ?? '';

      // " Başkanı" ekini silerek birim adını sadeleştir
      if (ad.endsWith(' Başkanı')) {
        ad = ad.replaceAll(' Başkanı', '').trim();
      }

      if (id != null && ad.isNotEmpty) {
        if (!zirhliListe.values.any((item) => item['temiz_ad'] == ad)) {
          zirhliListe[id] = {...b, 'temiz_ad': ad};
        }
      }
    }

    final sonListe = zirhliListe.values.toList();
    sonListe.sort(
        (a, b) => a['temiz_ad'].toString().compareTo(b['temiz_ad'].toString()));
    return sonListe;
  }

  List<Map<String, dynamic>> get _sorumluListesi =>
      _listeTemizle(widget.birimler
          .where((b) => _ilceUygun(b) && b['kategori'] != komisyonKategorisi));

  List<Map<String, dynamic>> get _komisyonListesi =>
      _listeTemizle(widget.birimler
          .where((b) => _ilceUygun(b) && b['kategori'] == komisyonKategorisi));

  // Sadece seçili il/ilçeye ait ve onaylanmış üyeleri getir
  List<Map<String, dynamic>> get _kisiListesi => widget.kisiler.where((k) {
        final onay = k['onay_durumu']?.toString().toLowerCase();
        final ilceEslesiyor = k['ilce_id']?.toString() == _ilceId;
        return (onay == 'onaylandı' || onay == 'onaylandi') && ilceEslesiyor;
      }).toList();

  Map<String, dynamic>? _birimBul(String? id) {
    if (id == null) return null;
    for (final b in widget.birimler) {
      if (b['id'].toString() == id) return b;
    }
    return null;
  }

  String? _idGecerli(List<Map<String, dynamic>> liste, dynamic id) {
    final s = id?.toString();
    if (s == null) return null;
    return liste.any((b) => b['id'].toString() == s) ? s : null;
  }

  String? _adlaBul(List<Map<String, dynamic>> liste, dynamic ad) {
    final aranan = ad.toString().replaceAll(' Başkanı', '').trim();
    for (final b in liste) {
      if (b['temiz_ad'] == aranan || b['ad'] == ad) return b['id'].toString();
    }
    return null;
  }

  String? _ilceBaslangic() {
    final m = widget.mevcut;
    if (m != null) return m['ilce_id']?.toString();
    if (!widget.yetki.admin) return widget.yetki.ilceId;
    final v = widget.varsayilanHedefId;
    if (v != null) {
      final b = _birimBul(v);
      if (b != null) return b['ilce_id']?.toString();
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final m = widget.mevcut;
    _baslik = TextEditingController(text: m?['baslik']?.toString() ?? '');
    final bugun = DateTime.now();
    _bas = DateTime(bugun.year, bugun.month, bugun.day);
    _bit = _bas;
    final r = tarihCoz(m?['tarih']?.toString());
    if (r != null) {
      _bas = r.start;
      _bit = r.end;
      _aralik = r.start != r.end;
    }
    final d = m?['durum']?.toString();
    if (d != null && durumlar.contains(d)) _durum = d;
    final o = m?['oncelik']?.toString();
    if (o != null && oncelikler.contains(o)) _oncelik = o;

    _ilceId = _ilceBaslangic();

    _sorumluId = _idGecerli(_sorumluListesi, m?['sorumlu_birim_id']) ??
        _adlaBul(_sorumluListesi, m?['olusturan_unvan']);
    if (_sorumluId == null && m == null && !_secebilir) {
      _sorumluId = _idGecerli(_sorumluListesi, widget.yetki.birimId) ??
          _adlaBul(_sorumluListesi, widget.yetki.birimAdi);
    }
    _hedefId = _idGecerli(_komisyonListesi, m?['hedef_birim_id']) ??
        _adlaBul(_komisyonListesi, m?['hedef_birim']) ??
        _idGecerli(_komisyonListesi, widget.varsayilanHedefId);
    final ak = m?['atanan_kisi_id']?.toString();
    _kisiId = _kisiListesi.any((k) => k['id'].toString() == ak) ? ak : null;
  }

  @override
  void dispose() {
    _baslik.dispose();
    super.dispose();
  }

  void _ilceDegisti(String? v) {
    setState(() {
      _ilceId = v == 'il' ? null : v;
      _sorumluId = null;
      _hedefId = null;
      _kisiId = null; // İlçe değişince kişi seçimi sıfırlanır
    });
  }

  Widget _temali(BuildContext c, Widget? child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              onPrimary: Colors.black,
              surface: kutuRengi),
        ),
        child: child!,
      );

  Future<void> _tarihSec() async {
    final simdi = DateTime.now();
    final ilk = DateTime(math.min(simdi.year - 1, _bas.year));
    final son = DateTime(math.max(simdi.year + 5, _bit.year), 12, 31);
    if (_aralik) {
      final r = await showDateRangePicker(
        context: context,
        firstDate: ilk,
        lastDate: son,
        initialDateRange: DateTimeRange(start: _bas, end: _bit),
        builder: _temali,
      );
      if (r != null) {
        setState(() {
          _bas = r.start;
          _bit = r.end;
        });
      }
    } else {
      final d = await showDatePicker(
        context: context,
        firstDate: ilk,
        lastDate: son,
        initialDate: _bas,
        builder: _temali,
      );
      if (d != null) {
        setState(() {
          _bas = d;
          _bit = d;
        });
      }
    }
  }

  Future<void> _kaydet() async {
    final baslik = _baslik.text.trim();
    if (baslik.isEmpty) {
      bildir(context, 'Lütfen faaliyet adını yazın.', renk: Colors.orange);
      return;
    }
    if (_hedefId == null) {
      bildir(context, 'Lütfen Hedef Komisyon seçiniz!', renk: Colors.orange);
      return;
    }
    if (_secebilir && _sorumluId == null) {
      bildir(context, 'Lütfen Sorumlu Birim seçiniz!', renk: Colors.orange);
      return;
    }

    String sorumluAd = widget.yetki.birimAdi;
    if (_sorumluId != null) {
      final secilenSorumlu = _sorumluListesi
          .where((b) => b['id'].toString() == _sorumluId)
          .firstOrNull;
      if (secilenSorumlu != null) {
        sorumluAd = secilenSorumlu['temiz_ad']?.toString() ??
            secilenSorumlu['ad'].toString();
      }
    }

    if (sorumluAd.isEmpty) {
      bildir(context,
          'Biriminiz tanımlı değil. Yöneticinizden birim ataması isteyin.',
          renk: Colors.orange);
      return;
    }

    final secilenHedef = _komisyonListesi
        .where((b) => b['id'].toString() == _hedefId)
        .firstOrNull;
    final hedefAd = secilenHedef != null
        ? (secilenHedef['temiz_ad']?.toString() ??
            secilenHedef['ad'].toString())
        : '';

    final kisi =
        widget.kisiler.where((k) => k['id'].toString() == _kisiId).firstOrNull;

    final veri = <String, dynamic>{
      'baslik': baslik,
      'tarih': aralikYaz(_bas, _aralik ? _bit : null),
      'baslangic_tarihi': isoTarih(_bas),
      'bitis_tarihi': _aralik ? isoTarih(_bit) : null,
      'durum': _durum,
      'oncelik': _oncelik,
      'atanan_kisi_id': _kisiId,
      'sorumlu_kisi_ad': kisi == null ? '' : tamAdGetir(kisi),
      'hedef_birim_id': _hedefId,
      'hedef_birim': hedefAd,
      'sorumlu_birim_id': _sorumluId ?? widget.yetki.birimId,
      'olusturan_unvan': sorumluAd,
      'ilce_id': _ilceId,
    };

    if (widget.mevcut == null) {
      veri['atayan_ad'] = widget.yetki.atayanEtiketi;
      veri['kategori'] = 'Genel';
      veri['onay_durumu'] = _secebilir ? 'Onaylandı' : 'Bekliyor';
    } else {
      if (!_secebilir) {
        veri['onay_durumu'] = 'Bekliyor';
      }
    }

    setState(() => _kaydediliyor = true);
    final ok = await FaaliyetServisi.kaydet(context,
        mevcut: widget.mevcut, veri: veri);
    if (!mounted) return;
    if (ok) {
      if (!_secebilir && veri['onay_durumu'] == 'Bekliyor') {
        bildir(context,
            'Kayıt başarılı. Yöneticilerin onayı sonrasında listelenecektir.',
            renk: Colors.blueAccent);
      }
      Navigator.pop(context, true);
    } else {
      setState(() => _kaydediliyor = false);
    }
  }

  Widget _birimDropdown({
    required String anahtar,
    required String label,
    required IconData icon,
    required List<Map<String, dynamic>> liste,
    required String? deger,
    required ValueChanged<String?> onChanged,
  }) {
    String? guvenliDeger = deger;
    if (guvenliDeger != null &&
        !liste.any((b) => b['id'].toString() == guvenliDeger)) {
      guvenliDeger = null;
    }

    return DropdownButtonFormField<String>(
      key: ValueKey('${anahtar}_$_ilceId'),
      initialValue: guvenliDeger,
      isExpanded: true,
      dropdownColor: AppColors.inputFill,
      style: const TextStyle(color: Colors.white),
      decoration: koyuInput(label: label, icon: icon),
      items: liste
          .map((b) => DropdownMenuItem<String>(
              value: b['id'].toString(),
              child: Text(b['temiz_ad'].toString(),
                  overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _kilitli(IconData ikon, String metin) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(ikon,
                color: Colors.tealAccent.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(metin,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ),
          ],
        ),
      );

  Widget _tarihKutusu() {
    final metin =
        _aralik ? '${tarihYaz(_bas)}  →  ${tarihYaz(_bit)}' : tarihYaz(_bas);
    return InkWell(
      onTap: _tarihSec,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: AppColors.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(metin,
                    style: const TextStyle(color: Colors.white, fontSize: 15))),
            const Icon(Icons.edit_calendar, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guncelleme = widget.mevcut != null;
    final kilitliBirim =
        _birimBul(_sorumluId)?['ad']?.toString() ?? widget.yetki.birimAdi;

    return Dialog(
      backgroundColor: kutuRengi,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      guncelleme ? 'Faaliyeti Düzenle' : 'Yeni Faaliyet Ekle',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: _kaydediliyor
                        ? null
                        : () => Navigator.pop(context, false)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _baslik,
              style: const TextStyle(color: Colors.white),
              decoration:
                  koyuInput(label: 'Faaliyet Adı', icon: Icons.description),
            ),
            const SizedBox(height: 16),
            if (widget.yetki.admin)
              DropdownButtonFormField<String>(
                initialValue: _ilceId ?? 'il',
                isExpanded: true,
                dropdownColor: AppColors.inputFill,
                style: const TextStyle(color: Colors.white),
                decoration: koyuInput(
                    label: 'İlçe / Teşkilat', icon: Icons.location_city),
                items: [
                  const DropdownMenuItem(
                      value: 'il', child: Text('İl (Merkez)')),
                  ...Ilceler.liste.map((i) => DropdownMenuItem(
                      value: i['id'].toString(),
                      child: Text(i['ad'].toString()))),
                ],
                onChanged: _ilceDegisti,
              )
            else
              _kilitli(Icons.location_city, 'İlçe: ${Ilceler.ad(_ilceId)}'),
            const SizedBox(height: 16),
            if (_secebilir)
              _birimDropdown(
                anahtar: 'sorumlu',
                label: 'Sorumlu Birim (Görevlendirilen)',
                icon: Icons.account_balance,
                liste: _sorumluListesi,
                deger: _sorumluId,
                onChanged: (v) => setState(() => _sorumluId = v),
              )
            else
              _kilitli(Icons.lock, 'Sorumlu Birim: $kilitliBirim'),
            const SizedBox(height: 16),
            _birimDropdown(
              anahtar: 'hedef',
              label: 'Faaliyet Alanı / Hedef Komisyon',
              icon: Icons.groups,
              liste: _komisyonListesi,
              deger: _hedefId,
              onChanged: (v) => setState(() => _hedefId = v),
            ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: ValueKey('kisi_$_ilceId'),
              child: kisiDropdown(
                kisiler: _kisiListesi,
                deger: _kisiId,
                etiketMetni: 'Özel Sorumlu Kişi (Bildirim Gider)',
                bosMetin: 'Henüz Atanmadı',
                onChanged: (v) => setState(() => _kisiId = v),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Tarih Aralığı Seç (Kamp, Sınav vb.)',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              value: _aralik,
              activeThumbColor: AppColors.accent,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() {
                _aralik = v;
                if (!v) {
                  _bit = _bas;
                } else if (_bit.isBefore(_bas)) {
                  _bit = _bas;
                }
              }),
            ),
            _tarihKutusu(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _durum,
                    isExpanded: true,
                    dropdownColor: AppColors.inputFill,
                    style: const TextStyle(color: Colors.white),
                    decoration: koyuInput(
                        label: 'Durum', icon: Icons.stacked_bar_chart),
                    items: durumlar
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _durum = v ?? _durum),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _oncelik,
                    isExpanded: true,
                    dropdownColor: AppColors.inputFill,
                    style: const TextStyle(color: Colors.white),
                    decoration: koyuInput(label: 'Öncelik', icon: Icons.flag),
                    items: oncelikler
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _oncelik = v ?? _oncelik),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _kaydediliyor ? null : _kaydet,
              icon: _kaydediliyor
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.check, size: 20),
              label: Text(guncelleme ? 'Güncelle' : 'Kaydet ve Bildir',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
