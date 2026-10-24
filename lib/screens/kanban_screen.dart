import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/notification_service.dart';

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  String _seciliBirimFiltre = 'Tümü';
  List<String> _birimListesi = ['Tümü'];

  @override
  void initState() {
    super.initState();
    _birimleriGetir();
  }

  Future<void> _birimleriGetir() async {
    try {
      final data =
          await supabase.from('birimler').select('ad').order('created_at');
      if (mounted) {
        setState(() {
          _birimListesi = ['Tümü', ...data.map((e) => e['ad'].toString())];
        });
      }
    } catch (_) {}
  }

  Future<void> _durumGuncelle(dynamic id, String yeniDurum) async {
    await supabase
        .from('faaliyetler')
        .update({'durum': yeniDurum}).eq('id', id);
  }

  Future<void> _hizliGorevEkle(String varsayilanDurum) async {
    final baslikCtrl = TextEditingController();
    List<String> birimler = _birimListesi.where((b) => b != 'Tümü').toList();
    if (birimler.isEmpty) birimler = ['Genel Yönetim'];
    String seciliBirim = birimler.first;

    List<Map<String, dynamic>> yoneticiler = [];
    try {
      final pData = await supabase
          .from('profiller')
          .select('id, ad, soyad, unvan')
          .order('ad');
      yoneticiler = List<Map<String, dynamic>>.from(pData);
    } catch (_) {}

    String? seciliKisiId =
        yoneticiler.isNotEmpty ? yoneticiler.first['id'].toString() : null;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF161C1A),
          title: Text('$varsayilanDurum Sütununa Ekle',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: baslikCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Görev Başlığı',
                    labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: seciliBirim,
                dropdownColor: AppColors.inputFill,
                style: const TextStyle(color: Colors.white),
                items: birimler
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setModalState(() => seciliBirim = v!),
                decoration: const InputDecoration(
                    labelText: 'Birim',
                    labelStyle: TextStyle(color: Colors.white54)),
              ),
              if (yoneticiler.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: seciliKisiId,
                  isExpanded: true,
                  dropdownColor: AppColors.inputFill,
                  style: const TextStyle(color: Colors.white),
                  items: yoneticiler.map((y) {
                    final ad = '${y['ad'] ?? ''} ${y['soyad'] ?? ''}'.trim();
                    return DropdownMenuItem(
                        value: y['id'].toString(),
                        child: Text(ad.isEmpty ? 'Yönetici' : ad,
                            overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (v) => setModalState(() => seciliKisiId = v),
                  decoration: const InputDecoration(
                      labelText: 'Atanan Kişi',
                      labelStyle: TextStyle(color: Colors.white54)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal',
                    style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black),
              onPressed: () async {
                if (baslikCtrl.text.trim().isEmpty) return;
                final bugun = DateTime.now();
                const aylar = [
                  'Ocak',
                  'Şubat',
                  'Mart',
                  'Nisan',
                  'Mayıs',
                  'Haziran',
                  'Temmuz',
                  'Ağustos',
                  'Eylül',
                  'Ekim',
                  'Kasım',
                  'Aralık'
                ];
                final tarihStr =
                    '${bugun.day} ${aylar[bugun.month - 1]} ${bugun.year}';

                String sorumluAdi = seciliBirim;
                if (seciliKisiId != null && yoneticiler.isNotEmpty) {
                  final p = yoneticiler
                      .firstWhere((e) => e['id'].toString() == seciliKisiId);
                  sorumluAdi =
                      '${p['ad'] ?? ''} ${p['soyad'] ?? ''} (${p['unvan'] ?? ''})'
                          .trim();
                }

                await supabase.from('faaliyetler').insert({
                  'baslik': baslikCtrl.text.trim(),
                  'tarih': tarihStr,
                  'durum': varsayilanDurum,
                  'oncelik': 'Normal',
                  'kategori': 'Genel',
                  'hedef_birim': seciliBirim,
                  'olusturan_unvan': sorumluAdi,
                  'atanan_kisi_id': seciliKisiId,
                });

                if (seciliKisiId != null) {
                  await NotificationService.gorevBildirimiGonder(
                    hedefKullaniciId: seciliKisiId!,
                    faaliyetBaslik: baslikCtrl.text.trim(),
                    tarih: tarihStr,
                    birim: seciliBirim,
                  );
                }

                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Ekle',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Kanban İş Takibi',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          backgroundColor: AppColors.secondary,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'Yapılacak'),
              Tab(text: 'Yapılıyor'),
              Tab(text: 'Tamamlandı'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.card,
              child: Row(
                children: [
                  const Icon(Icons.filter_list,
                      color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  const Text('Birim Filtresi:',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _birimListesi.contains(_seciliBirimFiltre)
                            ? _seciliBirimFiltre
                            : 'Tümü',
                        dropdownColor: AppColors.inputFill,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        items: _birimListesi
                            .map((b) =>
                                DropdownMenuItem(value: b, child: Text(b)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _seciliBirimFiltre = v!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase.from('faaliyetler').stream(
                    primaryKey: ['id']).order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.accent));
                  }

                  var tumListe = snapshot.data!;
                  if (_seciliBirimFiltre != 'Tümü') {
                    tumListe = tumListe
                        .where((f) => f['hedef_birim'] == _seciliBirimFiltre)
                        .toList();
                  }

                  return TabBarView(
                    children: [
                      _sutunOlustur(
                          tumListe, 'Yapılacak', Colors.lightBlueAccent),
                      _sutunOlustur(tumListe, 'Yapılıyor', Colors.orangeAccent),
                      _sutunOlustur(tumListe, 'Tamamlandı', Colors.greenAccent),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sutunOlustur(
      List<Map<String, dynamic>> tumListe, String durumAdi, Color vurguRengi) {
    final liste = tumListe.where((f) => f['durum'] == durumAdi).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: durumAdi,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        onPressed: () => _hizliGorevEkle(durumAdi),
        icon: const Icon(Icons.add),
        label: const Text('Görev Ekle',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: liste.isEmpty
          ? Center(
              child: Text('$durumAdi aşamasında görev yok.',
                  style: const TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: liste.length,
              itemBuilder: (context, index) {
                final f = liste[index];
                return Card(
                  color: AppColors.card,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: vurguRengi.withValues(alpha: 0.4)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f['baslik'] ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                            '🏢 ${f['hedef_birim'] ?? '-'}  |  📅 ${f['tarih'] ?? '-'}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('👤 ${f['olusturan_unvan'] ?? '-'}',
                            style: const TextStyle(
                                color: AppColors.accent, fontSize: 12)),
                        const Divider(color: Colors.white12, height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (durumAdi != 'Yapılacak')
                              TextButton.icon(
                                onPressed: () =>
                                    _durumGuncelle(f['id'], 'Yapılacak'),
                                icon: const Icon(Icons.undo,
                                    size: 16, color: Colors.lightBlueAccent),
                                label: const Text('Yapılacak',
                                    style: TextStyle(
                                        color: Colors.lightBlueAccent,
                                        fontSize: 12)),
                              ),
                            if (durumAdi != 'Yapılıyor')
                              TextButton.icon(
                                onPressed: () =>
                                    _durumGuncelle(f['id'], 'Yapılıyor'),
                                icon: const Icon(Icons.play_arrow,
                                    size: 16, color: Colors.orangeAccent),
                                label: const Text('Yapılıyor',
                                    style: TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 12)),
                              ),
                            if (durumAdi != 'Tamamlandı')
                              TextButton.icon(
                                onPressed: () =>
                                    _durumGuncelle(f['id'], 'Tamamlandı'),
                                icon: const Icon(Icons.check_circle,
                                    size: 16, color: Colors.greenAccent),
                                label: const Text('Tamamla',
                                    style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 12)),
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
