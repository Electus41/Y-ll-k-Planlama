import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/faaliyet_servisi.dart';
import '../core/ortak.dart';
import '../widgets/faaliyet_form_dialog.dart';
import 'faaliyet_detay_screen.dart';

class AcademyCalendarScreen extends StatefulWidget {
  const AcademyCalendarScreen({super.key});

  @override
  State<AcademyCalendarScreen> createState() => _AcademyCalendarScreenState();
}

class _AcademyCalendarScreenState extends State<AcademyCalendarScreen> {
  late int _yil;
  int? _ay; // null = Tümü
  String _komisyon = 'Tümü';
  List<String> _komisyonlar = ['Tümü'];
  Yetki? _yetki;
  late final Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    final simdi = DateTime.now();
    _yil = simdi.year;
    _ay = simdi.month - 1;
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

      // Başkanları takvim filtrelerinden gizler
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
    });
  }

  bool _gorunur(Map<String, dynamic> f) {
    if (_komisyon != 'Tümü' && f['hedef_birim'] != _komisyon) return false;
    final r = tarihCoz(f['tarih']?.toString());
    if (r == null) {
      final t = (f['tarih'] ?? '').toString();
      return t.contains('$_yil') && (_ay == null || t.contains(aylar[_ay!]));
    }
    final bas =
        _ay == null ? DateTime(_yil, 1, 1) : DateTime(_yil, _ay! + 1, 1);
    final bit =
        _ay == null ? DateTime(_yil, 12, 31) : DateTime(_yil, _ay! + 2, 0);
    return !r.start.isAfter(bit) && !r.end.isBefore(bas);
  }

  String _gunMetni(Map<String, dynamic> f) {
    final r = tarihCoz(f['tarih']?.toString());
    if (r == null) return '-';
    return r.start == r.end ? '${r.start.day}' : '${r.start.day}-${r.end.day}';
  }

  Widget _chipSatiri(List<String> secenekler, bool Function(String) secili,
      void Function(String) sec, Color secilenRenk, bool koyuYazi) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: secenekler.map((e) {
          final s = secili(e);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e),
              selected: s,
              onSelected: (_) => setState(() => sec(e)),
              backgroundColor: Colors.transparent,
              selectedColor: secilenRenk,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.white24)),
              labelStyle: TextStyle(
                  color: s
                      ? (koyuYazi ? Colors.black : AppColors.accent)
                      : Colors.white70,
                  fontWeight: s ? FontWeight.bold : FontWeight.normal),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buYil = DateTime.now().year;
    final yillar = List<int>.generate(6, (i) => buYil - 1 + i);
    if (!yillar.contains(_yil)) yillar.add(_yil);
    final yazabilir = _yetki?.yazabilir ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Yıllık Planlama Takvimi',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          DropdownButton<int>(
            value: _yil,
            dropdownColor: AppColors.card,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            items: yillar
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _yil = v);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: yazabilir
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              onPressed: () => faaliyetFormuAc(context),
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('Plan Ekle',
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
            child: Column(
              children: [
                _chipSatiri(
                  ['Tümü', ...aylar],
                  (e) => e == 'Tümü' ? _ay == null : _ay == aylar.indexOf(e),
                  (e) => _ay = e == 'Tümü' ? null : aylar.indexOf(e),
                  AppColors.accent,
                  true,
                ),
                const SizedBox(height: 8),
                _chipSatiri(
                  _komisyonlar,
                  (e) => _komisyon == e,
                  (e) => _komisyon = e,
                  AppColors.card,
                  false,
                ),
              ],
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
                final liste =
                    tarihSirali(snapshot.data!.where(_gorunur).toList());
                if (liste.isEmpty) {
                  return const Center(
                      child: Text('Bu döneme ait plan bulunmuyor.',
                          style: TextStyle(color: Colors.white54)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: liste.length,
                  itemBuilder: (context, index) {
                    final f = liste[index];
                    final yonet = _yetki?.yonetebilir(f) ?? false;
                    final kisi = (f['sorumlu_kisi_ad'] ?? '').toString();

                    return Card(
                      color: Colors.transparent,
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white12)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => FaaliyetDetayScreen(
                                    faaliyetId: f['id'].toString()))),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.2),
                                    shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Text(_gunMetni(f),
                                    style: const TextStyle(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                    textAlign: TextAlign.center),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(f['baslik']?.toString() ?? '',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                        '📅 ${tarihGoster(f['tarih']?.toString())}',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                    Text(
                                        '🏢 Sorumlu: ${f['olusturan_unvan'] ?? 'Belirtilmedi'}',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                    if (kisi.isNotEmpty)
                                      Text('👤 Kişi: $kisi',
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12)),
                                    Text(
                                        '🎯 Hedef: ${f['hedef_birim'] ?? 'Genel'}',
                                        style: const TextStyle(
                                            color: Colors.orangeAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                    if ((f['konum_adi'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text('📍 ${f['konum_adi']}',
                                          style: const TextStyle(
                                              color: Colors.lightBlueAccent,
                                              fontSize: 12)),
                                    const SizedBox(height: 2),
                                    Text('✍️ Atayan: ${f['atayan_ad'] ?? '-'}',
                                        style: const TextStyle(
                                            color: AppColors.accent,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color:
                                            durumRengi(f['durum']?.toString())
                                                .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                        f['durum']?.toString() ?? 'Yapılacak',
                                        style: TextStyle(
                                            color: durumRengi(
                                                f['durum']?.toString()),
                                            fontSize: 11)),
                                  ),
                                  if (yonet) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              size: 20,
                                              color: Colors.blueAccent),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          onPressed: () => faaliyetFormuAc(
                                              context,
                                              mevcut: f),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              size: 20,
                                              color: Colors.redAccent),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          onPressed: () =>
                                              FaaliyetServisi.sil(context, f),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
