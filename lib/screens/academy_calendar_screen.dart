import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/notification_service.dart';

class AcademyCalendarScreen extends StatefulWidget {
  const AcademyCalendarScreen({super.key});

  @override
  State<AcademyCalendarScreen> createState() => _AcademyCalendarScreenState();
}

class _AcademyCalendarScreenState extends State<AcademyCalendarScreen> {
  final List<String> aylar = [
    'Tümü',
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

  late String seciliAyFiltresi;
  String seciliYilFiltresi = DateTime.now().year.toString();

  @override
  void initState() {
    super.initState();
    seciliAyFiltresi = aylar[DateTime.now().month];
    if (!['2026', '2027', '2028', '2029', '2030'].contains(seciliYilFiltresi)) {
      seciliYilFiltresi = '2026';
    }
  }

  Future<void> _takvimdenPlanEkle() async {
    List<String> dinamikBirimler = [];
    List<Map<String, dynamic>> yoneticiler = [];

    try {
      final bData =
          await supabase.from('birimler').select('ad').order('created_at');
      dinamikBirimler = bData.map((e) => e['ad'].toString()).toList();
    } catch (_) {}

    try {
      final pData = await supabase
          .from('profiller')
          .select('id, ad, soyad, unvan')
          .order('ad');
      yoneticiler = List<Map<String, dynamic>>.from(pData);
    } catch (_) {}

    if (dinamikBirimler.isEmpty) dinamikBirimler = ['Genel Yönetim'];
    if (!mounted) return;

    final baslikCtrl = TextEditingController();
    String seciliGun = DateTime.now().day.toString();
    String seciliAy = seciliAyFiltresi == 'Tümü'
        ? aylar[DateTime.now().month]
        : seciliAyFiltresi;
    String seciliBirim = dinamikBirimler.first;
    String? seciliKisiId =
        yoneticiler.isNotEmpty ? yoneticiler.first['id'].toString() : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF161C1A),
          title: const Text('Takvime Plan Ekle',
              style: TextStyle(color: Colors.white, fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: baslikCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Etkinlik / Plan Başlığı',
                      labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: seciliGun,
                        dropdownColor: AppColors.inputFill,
                        style: const TextStyle(color: Colors.white),
                        items: List.generate(31, (i) => (i + 1).toString())
                            .map((g) =>
                                DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setModalState(() => seciliGun = v!),
                        decoration: const InputDecoration(
                            labelText: 'Gün',
                            labelStyle: TextStyle(color: Colors.white54)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: seciliAy,
                        dropdownColor: AppColors.inputFill,
                        style: const TextStyle(color: Colors.white),
                        items: aylar
                            .where((a) => a != 'Tümü')
                            .map((a) =>
                                DropdownMenuItem(value: a, child: Text(a)))
                            .toList(),
                        onChanged: (v) => setModalState(() => seciliAy = v!),
                        decoration: const InputDecoration(
                            labelText: 'Ay',
                            labelStyle: TextStyle(color: Colors.white54)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: seciliBirim,
                  isExpanded: true,
                  dropdownColor: AppColors.inputFill,
                  style: const TextStyle(color: Colors.white),
                  items: dinamikBirimler
                      .map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(b, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setModalState(() => seciliBirim = v!),
                  decoration: const InputDecoration(
                      labelText: 'Sorumlu Birim',
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
                      final adSoyad =
                          '${y['ad'] ?? ''} ${y['soyad'] ?? ''}'.trim();
                      return DropdownMenuItem(
                          value: y['id'].toString(),
                          child: Text(adSoyad.isEmpty ? 'Yönetici' : adSoyad,
                              overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (v) => setModalState(() => seciliKisiId = v),
                    decoration: const InputDecoration(
                        labelText: 'Atanan Sorumlu',
                        labelStyle: TextStyle(color: Colors.white54)),
                  ),
                ],
              ],
            ),
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
                final tarihStr = '$seciliGun $seciliAy $seciliYilFiltresi';

                String sorumluEtiket = seciliBirim;
                if (seciliKisiId != null && yoneticiler.isNotEmpty) {
                  final p = yoneticiler
                      .firstWhere((e) => e['id'].toString() == seciliKisiId);
                  sorumluEtiket =
                      '${p['ad'] ?? ''} ${p['soyad'] ?? ''} (${p['unvan'] ?? ''})'
                          .trim();
                }

                await supabase.from('faaliyetler').insert({
                  'baslik': baslikCtrl.text.trim(),
                  'tarih': tarihStr,
                  'durum': 'Yapılacak',
                  'oncelik': 'Normal',
                  'kategori': 'Takvim',
                  'hedef_birim': seciliBirim,
                  'olusturan_unvan': sorumluEtiket,
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
              child: const Text('Kaydet',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yıllık Planlama Takvimi',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: seciliYilFiltresi,
              dropdownColor: AppColors.inputFill,
              style: const TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.bold),
              items: ['2026', '2027', '2028', '2029', '2030']
                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                  .toList(),
              onChanged: (v) => setState(() => seciliYilFiltresi = v!),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        onPressed: _takvimdenPlanEkle,
        icon: const Icon(Icons.add),
        label: const Text('Plan Ekle',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            color: AppColors.card,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: aylar.map((ay) {
                  final secili = seciliAyFiltresi == ay;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(ay),
                      selected: secili,
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.inputFill,
                      labelStyle: TextStyle(
                        color: secili ? Colors.black : Colors.white70,
                        fontWeight:
                            secili ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setState(() => seciliAyFiltresi = ay),
                    ),
                  );
                }).toList(),
              ),
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

                final tumPlanlar = snapshot.data!.where((f) {
                  final tarih = (f['tarih'] ?? '').toString();
                  final yilUygun = tarih.contains(seciliYilFiltresi);
                  final ayUygun = seciliAyFiltresi == 'Tümü' ||
                      tarih.contains(seciliAyFiltresi);
                  return yilUygun && ayUygun;
                }).toList();

                if (tumPlanlar.isEmpty) {
                  return Center(
                    child: Text(
                      '$seciliAyFiltresi $seciliYilFiltresi döneminde planlanmış etkinlik bulunmuyor.',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tumPlanlar.length,
                  itemBuilder: (context, index) {
                    final plan = tumPlanlar[index];
                    final gunParca =
                        (plan['tarih'] ?? '').toString().split(' ').first;
                    return Card(
                      color: AppColors.card,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.secondary,
                          child: Text(gunParca,
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(plan['baslik'] ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${plan['tarih']} • ${plan['hedef_birim']}\n👤 ${plan['olusturan_unvan'] ?? '-'}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Chip(
                          label: Text(plan['durum'] ?? 'Yapılacak',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white)),
                          backgroundColor: plan['durum'] == 'Tamamlandı'
                              ? Colors.green.shade800
                              : Colors.blueGrey.shade800,
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
