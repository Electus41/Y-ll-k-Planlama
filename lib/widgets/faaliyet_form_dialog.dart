import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/faaliyet_servisi.dart';
import '../core/ortak.dart';

/// Faaliyet ekleme/düzenleme formu. Kaydedildiyse true döner.
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
        .select('id, ad, soyad, unvan')
        .order('ad'));
    birimler = List<Map<String, dynamic>>.from(await supabase
        .from('birimler')
        .select('id, ad, kategori')
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
  String? _sorumluId, _hedefId, _kisiId;
  String _durum = 'Yapılacak';
  String _oncelik = 'Normal';
  bool _kaydediliyor = false;

  // Sorumlu Birimde sadece İcra ve Yönetim (Başkanlar Hariç)
  List<Map<String, dynamic>> get _sorumluListesi => widget.birimler
      .where((b) =>
          b['kategori'] != komisyonKategorisi &&
          !b['ad'].toString().contains('Başkan'))
      .toList();

  // Hedef Komisyonda sadece Komisyonlar (Başkanlar Hariç)
  List<Map<String, dynamic>> get _komisyonListesi => widget.birimler
      .where((b) =>
          b['kategori'] == komisyonKategorisi &&
          !b['ad'].toString().contains('Başkan'))
      .toList();

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
    for (final b in liste) {
      if (b['ad'] == ad) return b['id'].toString();
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

    _sorumluId = _idGecerli(_sorumluListesi, m?['sorumlu_birim_id']) ??
        _adlaBul(_sorumluListesi, m?['olusturan_unvan']);
    if (_sorumluId == null && m == null && !widget.yetki.admin) {
      _sorumluId = _adlaBul(_sorumluListesi, widget.yetki.birim) ??
          _adlaBul(_sorumluListesi, widget.yetki.unvan);
    }
    _hedefId = _idGecerli(_komisyonListesi, m?['hedef_birim_id']) ??
        _adlaBul(_komisyonListesi, m?['hedef_birim']) ??
        _idGecerli(_komisyonListesi, widget.varsayilanHedefId);
    final ak = m?['atanan_kisi_id']?.toString();
    _kisiId = widget.kisiler.any((k) => k['id'].toString() == ak) ? ak : null;
  }

  @override
  void dispose() {
    _baslik.dispose();
    super.dispose();
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
    if (widget.yetki.admin && _sorumluId == null) {
      bildir(context, 'Lütfen Sorumlu Birim seçiniz!', renk: Colors.orange);
      return;
    }
    final sorumlu = _birimBul(_sorumluId);
    final sorumluAd = sorumlu?['ad']?.toString() ?? widget.yetki.birimAdi;
    if (sorumluAd.isEmpty) {
      bildir(context,
          'Biriminiz tanımlı değil. Yöneticinizden birim ataması isteyin.',
          renk: Colors.orange);
      return;
    }
    final hedef = _birimBul(_hedefId)!;
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
      'hedef_birim': hedef['ad'],
      'sorumlu_birim_id': sorumlu?['id'],
      'olusturan_unvan': sorumluAd,
    };
    if (widget.mevcut == null) {
      veri['atayan_ad'] = widget.yetki.atayanEtiketi;
      veri['kategori'] = 'Genel';
    }

    setState(() => _kaydediliyor = true);
    final ok = await FaaliyetServisi.kaydet(context,
        mevcut: widget.mevcut, veri: veri);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _kaydediliyor = false);
    }
  }

  Widget _birimDropdown({
    required String label,
    required IconData icon,
    required List<Map<String, dynamic>> liste,
    required String? deger,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: deger,
      isExpanded: true,
      dropdownColor: AppColors.inputFill,
      style: const TextStyle(color: Colors.white),
      decoration: koyuInput(label: label, icon: icon),
      items: liste
          .map((b) => DropdownMenuItem<String>(
              value: b['id'].toString(),
              child: Text(b['ad'].toString(), overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }

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
    final admin = widget.yetki.admin;
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
            if (admin)
              _birimDropdown(
                label: 'Sorumlu Birim (Görevlendirilen)',
                icon: Icons.account_balance,
                liste: _sorumluListesi,
                deger: _sorumluId,
                onChanged: (v) => setState(() => _sorumluId = v),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(Icons.lock,
                        color: Colors.tealAccent.withValues(alpha: 0.7),
                        size: 20),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text('Sorumlu Birim: $kilitliBirim',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _birimDropdown(
              label: 'Faaliyet Alanı / Hedef Komisyon',
              icon: Icons.groups,
              liste: _komisyonListesi,
              deger: _hedefId,
              onChanged: (v) => setState(() => _hedefId = v),
            ),
            const SizedBox(height: 16),
            kisiDropdown(
              kisiler: widget.kisiler,
              deger: _kisiId,
              etiketMetni: 'Özel Sorumlu Kişi (Bildirim Gider)',
              bosMetin: 'Henüz Atanmadı',
              onChanged: (v) => setState(() => _kisiId = v),
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
