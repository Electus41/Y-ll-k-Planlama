import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/faaliyet_servisi.dart';
import '../core/ortak.dart';
import 'faaliyet_detay_screen.dart';

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  Yetki? _yetki;
  bool _yuklendi = false;
  String _komisyon = 'Tümü';
  List<String> _komisyonlar = ['Tümü'];
  late final Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = supabase
        .from('faaliyetler')
        .stream(primaryKey: ['id']).order('created_at', ascending: false);
    _yukle();
  }

  Future<void> _yukle() async {
    final y = await Yetki.yukle();
    List<String> k = [];
    try {
      final d = await supabase
          .from('birimler')
          .select('ad')
          .eq('kategori', komisyonKategorisi)
          .order('sira');

      k = d
          .map<String>((b) => b['ad'].toString())
          .where((ad) => !ad.contains('Başkan'))
          .toList();
    } catch (e) {
      debugPrint('Komisyonlar alınamadı: $e');
    }
    if (!mounted) return;
    setState(() {
      _yetki = y;
      _komisyonlar = ['Tümü', ...k];
      _yuklendi = true;
    });
  }

  Future<void> _durumTasi(Map<String, dynamic> f, String yeni) async {
    if (f['durum'] == yeni) return;
    if (!(_yetki?.durumDegistirebilir(f) ?? false)) {
      bildir(context, 'Sadece kendi biriminize ait görevleri taşıyabilirsiniz!',
          renk: Colors.orange);
      return;
    }
    await FaaliyetServisi.durumGuncelle(context, f, yeni);
  }

  Future<void> _altGorevAc({Map<String, dynamic>? mevcut}) async {
    final yetki = _yetki;
    if (yetki == null || yetki.gonullu) return;

    List<Map<String, dynamic>> kisiler = [];
    List<Map<String, dynamic>> anaFaaliyetler = [];
    try {
      kisiler = List<Map<String, dynamic>>.from(await supabase
          .from('profiller')
          .select('id, ad, soyad, unvan')
          .order('ad'));
      final d = await supabase
          .from('faaliyetler')
          .select(
              'id, baslik, hedef_birim, hedef_birim_id, bagli_faaliyet_id, onay_durumu')
          .order('created_at', ascending: false);

      // SADECE ONAYLI ANA FAALİYETLERE ALT GÖREV EKLENEBİLİR
      anaFaaliyetler = List<Map<String, dynamic>>.from(d)
          .where((f) =>
              f['bagli_faaliyet_id'] == null && f['onay_durumu'] != 'Bekliyor')
          .toList();
    } catch (e) {
      debugPrint('Alt görev verileri alınamadı: $e');
      if (mounted) bildir(context, 'Veriler yüklenemedi.', renk: Colors.red);
      return;
    }
    if (!mounted) return;
    if (anaFaaliyetler.isEmpty) {
      bildir(context, 'Önce takvimden onaylı ana bir faaliyet eklemelisiniz!',
          renk: Colors.orange);
      return;
    }

    final baslikCtrl =
        TextEditingController(text: mevcut?['baslik']?.toString() ?? '');
    String? anaId = mevcut?['bagli_faaliyet_id']?.toString();
    if (!anaFaaliyetler.any((a) => a['id'].toString() == anaId)) {
      anaId = anaFaaliyetler.first['id'].toString();
    }
    final ak = mevcut?['atanan_kisi_id']?.toString();
    String? kisiId = kisiler.any((k) => k['id'].toString() == ak) ? ak : null;
    String durum = durumlar.contains(mevcut?['durum'])
        ? mevcut!['durum'] as String
        : 'Yapılacak';
    String oncelik = oncelikler.contains(mevcut?['oncelik'])
        ? mevcut!['oncelik'] as String
        : 'Normal';
    DateTime teslim =
        tarihCoz(mevcut?['tarih']?.toString())?.start ?? DateTime.now();
    bool kaydediliyor = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: kutuRengi,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setM) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        mevcut != null
                            ? 'Alt Görevi Düzenle'
                            : 'Yeni Alt Görev Ataması',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(dialogCtx)),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: anaId,
                  isExpanded: true,
                  items: anaFaaliyetler
                      .map((f) => DropdownMenuItem<String>(
                          value: f['id'].toString(),
                          child: Text(f['baslik'].toString(),
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setM(() => anaId = v),
                  dropdownColor: AppColors.inputFill,
                  style: const TextStyle(color: Colors.white),
                  decoration: koyuInput(
                      label: 'Bağlı Olduğu Ana Faaliyet',
                      icon: Icons.merge_type),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: baslikCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: koyuInput(
                      label: 'Alt Görev Adı (Örn: Otobüs Ayarlanacak)',
                      icon: Icons.task_alt),
                ),
                const SizedBox(height: 16),
                kisiDropdown(
                  kisiler: kisiler,
                  deger: kisiId,
                  etiketMetni: 'Görevi Yapacak Kişi (Bildirim Gider)',
                  bosMetin: 'Henüz Atanmadı',
                  onChanged: (v) => setM(() => kisiId = v),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Son Teslim / Bitiş Tarihi',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                  subtitle: Text(tarihYaz(teslim),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  trailing:
                      const Icon(Icons.calendar_month, color: AppColors.accent),
                  onTap: () async {
                    final s = DateTime.now();
                    final secilen = await showDatePicker(
                      context: context,
                      initialDate: teslim,
                      firstDate: DateTime(
                          teslim.year < s.year - 1 ? teslim.year : s.year - 1),
                      lastDate: DateTime(
                          teslim.year > s.year + 5 ? teslim.year : s.year + 5,
                          12,
                          31),
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                              primary: AppColors.accent,
                              onPrimary: Colors.black,
                              surface: kutuRengi),
                        ),
                        child: child!,
                      ),
                    );
                    if (secilen != null) setM(() => teslim = secilen);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: durum,
                        isExpanded: true,
                        items: durumlar
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setM(() => durum = v ?? durum),
                        dropdownColor: AppColors.inputFill,
                        style: const TextStyle(color: Colors.white),
                        decoration: koyuInput(
                            label: 'Durum', icon: Icons.stacked_bar_chart),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: oncelik,
                        isExpanded: true,
                        items: oncelikler
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setM(() => oncelik = v ?? oncelik),
                        dropdownColor: AppColors.inputFill,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            koyuInput(label: 'Öncelik', icon: Icons.flag),
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
                  onPressed: kaydediliyor
                      ? null
                      : () async {
                          final baslik = baslikCtrl.text.trim();
                          if (baslik.isEmpty) {
                            bildir(context, 'Alt görev adını yazın.',
                                renk: Colors.orange);
                            return;
                          }
                          final ana = anaFaaliyetler
                              .firstWhere((a) => a['id'].toString() == anaId);
                          final kisi = kisiler
                              .where((k) => k['id'].toString() == kisiId)
                              .firstOrNull;
                          final birimAdi =
                              yetki.birimAdi.isEmpty ? 'Genel' : yetki.birimAdi;

                          final veri = <String, dynamic>{
                            'baslik': baslik,
                            'tarih': tarihYaz(teslim),
                            'baslangic_tarihi': isoTarih(teslim),
                            'bitis_tarihi': null,
                            'durum': durum,
                            'oncelik': oncelik,
                            'atanan_kisi_id': kisiId,
                            'sorumlu_kisi_ad':
                                kisi == null ? '' : tamAdGetir(kisi),
                            'bagli_faaliyet_id': ana['id'],
                            'bagli_faaliyet_baslik': ana['baslik'],
                            'hedef_birim_id': ana['hedef_birim_id'],
                            'hedef_birim': ana['hedef_birim'] ?? 'Genel',
                            'olusturan_unvan': birimAdi,
                          };
                          if (mevcut == null) {
                            veri['atayan_ad'] = yetki.atayanEtiketi;
                            veri['kategori'] = 'Alt Görev';
                            // Alt görevler direkt onaylıdır
                            veri['onay_durumu'] = 'Onaylandı';
                          }

                          setM(() => kaydediliyor = true);
                          final ok = await FaaliyetServisi.kaydet(context,
                              mevcut: mevcut, veri: veri);
                          if (!context.mounted) return;
                          if (ok) {
                            Navigator.pop(dialogCtx);
                          } else {
                            setM(() => kaydediliyor = false);
                          }
                        },
                  icon: kaydediliyor
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.check, size: 20),
                  label: Text(mevcut != null ? 'Güncelle' : 'Alt Görevi Ata',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kanbanKarti(Map<String, dynamic> f) {
    final yonet = _yetki?.yonetebilir(f) ?? false;
    final durumDegisir = _yetki?.durumDegistirebilir(f) ?? false;
    final altGorev = f['bagli_faaliyet_baslik'] != null;
    final kisi = (f['sorumlu_kisi_ad'] ?? '').toString();

    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
              color: altGorev
                  ? Colors.tealAccent.withValues(alpha: 0.3)
                  : Colors.white12,
              width: altGorev ? 1.5 : 1.0)),
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    FaaliyetDetayScreen(faaliyetId: f['id'].toString()))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (altGorev)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('🔗 Ana Etkinlik: ${f['bagli_faaliyet_baslik']}',
                      style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: Text(f['baslik']?.toString() ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14))),
                  if (durumDegisir)
                    PopupMenuButton<String>(
                      color: AppColors.inputFill,
                      tooltip: 'Durumu değiştir',
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      icon: const Icon(Icons.swap_horiz,
                          color: Colors.orangeAccent),
                      onSelected: (v) => _durumTasi(f, v),
                      itemBuilder: (_) => durumlar
                          .where((d) => d != f['durum'])
                          .map((d) => PopupMenuItem(
                              value: d,
                              child: Text('→ $d',
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                    ),
                  if (yonet) ...[
                    GestureDetector(
                        onTap: () => _altGorevAc(mevcut: f),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.edit,
                              size: 18, color: Colors.blueAccent),
                        )),
                    GestureDetector(
                        onTap: () => FaaliyetServisi.sil(context, f),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.delete,
                              size: 18, color: Colors.redAccent),
                        )),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text('⏰ ${tarihGoster(f['tarih']?.toString())}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              if (kisi.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('👤 Atanan: $kisi',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 4),
              Text('🏢 Sorumlu: ${f['olusturan_unvan'] ?? '-'}',
                  style: const TextStyle(
                      color: Colors.orangeAccent, fontSize: 11)),
              Text('🎯 Hedef: ${f['hedef_birim'] ?? 'Genel'}',
                  style:
                      const TextStyle(color: AppColors.accent, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sutun(String baslik, List<Map<String, dynamic>> isler, Color renk) {
    return Container(
      width: 290,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: DragTarget<Map<String, dynamic>>(
        onAcceptWithDetails: (d) => _durumTasi(d.data, baslik),
        builder: (context, aday, _) {
          return Container(
            decoration: BoxDecoration(
              color: aday.isNotEmpty
                  ? renk.withValues(alpha: 0.1)
                  : AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border:
                  aday.isNotEmpty ? Border.all(color: renk, width: 2) : null,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: renk.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12))),
                  child: Center(
                      child: Text('$baslik (${isler.length})',
                          style: TextStyle(
                              color: renk,
                              fontWeight: FontWeight.bold,
                              fontSize: 14))),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: isler.length,
                    itemBuilder: (context, i) {
                      final f = isler[i];
                      if (!(_yetki?.durumDegistirebilir(f) ?? false)) {
                        return _kanbanKarti(f);
                      }
                      return LongPressDraggable<Map<String, dynamic>>(
                        data: f,
                        feedback: Material(
                            color: Colors.transparent,
                            child:
                                SizedBox(width: 280, child: _kanbanKarti(f))),
                        childWhenDragging:
                            Opacity(opacity: 0.3, child: _kanbanKarti(f)),
                        child: _kanbanKarti(f),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_yuklendi) {
      return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
              child: CircularProgressIndicator(color: AppColors.accent)));
    }

    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        title: const Text('Alt Görevler & İş Takibi',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: (_yetki?.yazabilir ?? false)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              onPressed: () => _altGorevAc(),
              icon: const Icon(Icons.add_task, color: Colors.black),
              label: const Text('Alt Görev Ata',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            )
          : null,
      body: Column(
        children: [
          Container(
            color: AppColors.background,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _komisyonlar.map((k) {
                  final s = _komisyon == k;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(k),
                      selected: s,
                      onSelected: (_) => setState(() => _komisyon = k),
                      backgroundColor: Colors.transparent,
                      selectedColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.white24)),
                      labelStyle: TextStyle(
                          color: s ? Colors.black : Colors.white70,
                          fontWeight: s ? FontWeight.bold : FontWeight.normal),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Veri alınamadı.',
                          style: TextStyle(color: Colors.redAccent)));
                }
                if (!snapshot.hasData) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent));
                }
                // ONAY BEKLEYENLERİ KANBANDAN GİZLİYORUZ
                var hepsi = snapshot.data!
                    .where((f) => f['onay_durumu'] != 'Bekliyor')
                    .toList();

                if (_komisyon != 'Tümü') {
                  hepsi = hepsi
                      .where((f) => f['hedef_birim'] == _komisyon)
                      .toList();
                }
                hepsi = tarihSirali(hepsi);
                List<Map<String, dynamic>> d(String s) =>
                    hepsi.where((f) => f['durum'] == s).toList();

                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _sutun('Yapılacak', d('Yapılacak'),
                            Colors.lightBlueAccent),
                        _sutun(
                            'Yapılıyor', d('Yapılıyor'), Colors.orangeAccent),
                        _sutun(
                            'Tamamlandı', d('Tamamlandı'), Colors.greenAccent),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
