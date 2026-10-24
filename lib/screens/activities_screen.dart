import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import 'academy_calendar_screen.dart';
import 'kanban_screen.dart';
import 'pdf_screen.dart';
import 'profile_screen.dart';
import 'units_screen.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  String secilenFiltre = 'Tümü';

  final List<String> aylar = [
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

  // Hint yerine Label kullanıldı, böylece başlıklar kaybolmaz
  InputDecoration _koyuInputDekorasyonu(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
      prefixIcon:
          Icon(icon, color: Colors.tealAccent.withValues(alpha: 0.7), size: 20),
      filled: true,
      fillColor: const Color(0xFF1F2624),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  Widget _tarihDropdown(
      {required String value,
      required List<String> items,
      required void Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      items:
          items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      dropdownColor: const Color(0xFF1F2624),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF1F2624),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Future<void> _faaliyetSil(String id) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF161C1A),
            title: const Text('Silmek İstediğinize Emin Misiniz?',
                style: TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('İptal',
                      style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sil', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await supabase.from('faaliyetler').delete().eq('id', id);
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Faaliyet silindi.'), backgroundColor: Colors.red));
    }
  }

  // MODAL AÇILIRKEN VERİTABANINDAN BİRİMLERİ DİNAMİK ÇEKİYORUZ
  Future<void> _faaliyetEkleModalAc(
      {Map<String, dynamic>? mevcutFaaliyet}) async {
    List<String> dinamikBirimler = [];
    try {
      final data =
          await supabase.from('birimler').select('ad').order('created_at');
      dinamikBirimler = data.map((e) => e['ad'].toString()).toList();
    } catch (e) {
      debugPrint('Birimler çekilemedi: $e');
    }

    if (dinamikBirimler.isEmpty) {
      dinamikBirimler = ['Birim Bulunamadı (Önce Birim Ekleyin)'];
    }

    if (!mounted) return;

    final baslikController =
        TextEditingController(text: mevcutFaaliyet?['baslik'] ?? '');

    DateTime sTarih = DateTime.now();
    if (mevcutFaaliyet != null && mevcutFaaliyet['tarih'] != null) {
      try {
        final parts = mevcutFaaliyet['tarih'].toString().split(' ');
        if (parts.length == 3)
          sTarih = DateTime(int.parse(parts[2]), aylar.indexOf(parts[1]) + 1,
              int.parse(parts[0]));
      } catch (_) {}
    }

    String seciliGun = sTarih.day.toString();
    String seciliAy = aylar[sTarih.month - 1];
    String seciliYil = sTarih.year.toString();

    String durum = mevcutFaaliyet?['durum'] ?? 'Yapılacak';
    String oncelik = mevcutFaaliyet?['oncelik'] ?? 'Normal';

    // Veritabanı çakışmalarını önlemek için güvenlik kontrolü (contains)
    String hedefBirim = mevcutFaaliyet?['hedef_birim'] ?? dinamikBirimler.first;
    if (!dinamikBirimler.contains(hedefBirim)) {
      hedefBirim = dinamikBirimler.first;
    }

    String secilenSorumlu =
        mevcutFaaliyet?['olusturan_unvan'] ?? dinamikBirimler.first;
    if (!dinamikBirimler.contains(secilenSorumlu)) {
      secilenSorumlu = dinamikBirimler.first;
    }

    bool isUpdate = mevcutFaaliyet != null;

    showDialog(
      context: context,
      builder: (modalContext) => Dialog(
        backgroundColor: const Color(0xFF161C1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setModalState) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up,
                        color: Colors.tealAccent.withValues(alpha: 0.8),
                        size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            isUpdate
                                ? 'Faaliyeti Düzenle'
                                : 'Yeni Faaliyet Ekle',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold))),
                    IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                    controller: baslikController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _koyuInputDekorasyonu(
                        label: 'Faaliyet Adı', icon: Icons.description)),
                const SizedBox(height: 16),
                const Text('Faaliyet / İşlem Tarihi:',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        flex: 2,
                        child: _tarihDropdown(
                            value: seciliGun,
                            items: List.generate(31, (i) => (i + 1).toString()),
                            onChanged: (val) =>
                                setModalState(() => seciliGun = val!))),
                    const SizedBox(width: 8),
                    Expanded(
                        flex: 3,
                        child: _tarihDropdown(
                            value: seciliAy,
                            items: aylar,
                            onChanged: (val) =>
                                setModalState(() => seciliAy = val!))),
                    const SizedBox(width: 8),
                    Expanded(
                        flex: 2,
                        child: _tarihDropdown(
                            value: seciliYil,
                            items: ['2026', '2027', '2028', '2029', '2030'],
                            onChanged: (val) =>
                                setModalState(() => seciliYil = val!))),
                  ],
                ),
                const SizedBox(height: 16),

                // İki dropdown da artık dinamikBirimler'den besleniyor
                DropdownButtonFormField<String>(
                    value: hedefBirim,
                    items: dinamikBirimler
                        .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) => setModalState(() => hedefBirim = val!),
                    dropdownColor: const Color(0xFF1F2624),
                    style: const TextStyle(color: Colors.white),
                    decoration: _koyuInputDekorasyonu(
                        label: 'Sorumlu Birim / Komisyon', icon: Icons.domain)),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                    value: secilenSorumlu,
                    items: dinamikBirimler
                        .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) =>
                        setModalState(() => secilenSorumlu = val!),
                    dropdownColor: const Color(0xFF1F2624),
                    style: const TextStyle(color: Colors.white),
                    decoration: _koyuInputDekorasyonu(
                        label: 'Görevi Oluşturan Kişi / Yetkili',
                        icon: Icons.person)),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                        child: DropdownButtonFormField<String>(
                            value: durum,
                            items: ['Yapılacak', 'Yapılıyor', 'Tamamlandı']
                                .map((e) =>
                                    DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (val) =>
                                setModalState(() => durum = val!),
                            dropdownColor: const Color(0xFF1F2624),
                            style: const TextStyle(color: Colors.white),
                            decoration: _koyuInputDekorasyonu(
                                label: 'Durum',
                                icon: Icons.stacked_bar_chart))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: DropdownButtonFormField<String>(
                            value: oncelik,
                            items: ['Acil', 'Normal', 'Düşük']
                                .map((e) =>
                                    DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (val) =>
                                setModalState(() => oncelik = val!),
                            dropdownColor: const Color(0xFF1F2624),
                            style: const TextStyle(color: Colors.white),
                            decoration: _koyuInputDekorasyonu(
                                label: 'Öncelik', icon: Icons.flag))),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF69F0AE),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    if (baslikController.text.isNotEmpty) {
                      String tarihStr = '$seciliGun $seciliAy$seciliYil';
                      if (isUpdate) {
                        await supabase.from('faaliyetler').update({
                          'baslik': baslikController.text,
                          'tarih': tarihStr,
                          'durum': durum,
                          'oncelik': oncelik,
                          'hedef_birim': hedefBirim,
                          'olusturan_unvan': secilenSorumlu
                        }).eq('id', mevcutFaaliyet['id']);
                      } else {
                        await supabase.from('faaliyetler').insert({
                          'baslik': baslikController.text,
                          'tarih': tarihStr,
                          'durum': durum,
                          'kategori': 'Eğitim',
                          'oncelik': oncelik,
                          'hedef_birim': hedefBirim,
                          'olusturan_unvan': secilenSorumlu
                        });
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('Kaydet',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _whatsappOzetKopyala(List<Map<String, dynamic>> faaliyetler) {
    String metin = "📌 *KOCAELİ GENÇ İHH YILLIK PLAN*\n\n";
    for (var f in faaliyetler)
      metin +=
          "🔹 *${f['baslik']}*\n📅 ${f['tarih']}\n📌 Durum: ${f['durum']}\n👤 Sorumlu: ${f['olusturan_unvan']}\n\n";
    Clipboard.setData(ClipboardData(text: metin));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp özeti panoya kopyalandı!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B4D3E),
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/images/logo.png', height: 30),
          const SizedBox(width: 10),
          const Text('Kocaeli Genç İHH',
              style: TextStyle(color: Colors.white, fontSize: 16))
        ]),
        backgroundColor: const Color(0xFF121816),
        actions: [
          IconButton(
              icon: const Icon(Icons.person, color: Colors.white),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProfileScreen())))
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('faaliyetler')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .map((maps) => List<Map<String, dynamic>>.from(maps)),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('Veri çekilemedi.\nHata: ${snapshot.error}',
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 14))));
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF69F0AE)));
          }

          final List<Map<String, dynamic>> faaliyetler = snapshot.hasData
              ? List<Map<String, dynamic>>.from(snapshot.data!)
              : [];
          final planlananSayisi =
              faaliyetler.where((f) => f['durum'] == 'Yapılacak').length;
          final yapiliyorSayisi =
              faaliyetler.where((f) => f['durum'] == 'Yapılıyor').length;
          final tamamlananSayisi =
              faaliyetler.where((f) => f['durum'] == 'Tamamlandı').length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF121816), Color(0xFF1A2220)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2)
                      ]),
                  child: Column(
                    children: [
                      const Text('CANLI FAALİYET & PLAN ÖZETİ',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _istatistikKolon('Planlanan', '$planlananSayisi',
                              Colors.lightBlueAccent),
                          Container(
                              height: 30, width: 1, color: Colors.white24),
                          _istatistikKolon('Yapılıyor', '$yapiliyorSayisi',
                              Colors.orangeAccent),
                          Container(
                              height: 30, width: 1, color: Colors.white24),
                          _istatistikKolon('Tamamlandı', '$tamamlananSayisi',
                              Colors.greenAccent),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Hızlı İşlemler & Modüller',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 12),
                _modulSatiri(
                    context,
                    'Yeni Faaliyet Ekle',
                    'Planlanan yeni bir etkinlik tanımlayın',
                    Icons.add_box,
                    Colors.tealAccent,
                    () => _faaliyetEkleModalAc()),
                const SizedBox(height: 10),
                _modulSatiri(
                    context,
                    'Görev & İş Takibi (Kanban)',
                    'Faaliyetleri sütunlar halinde yönetin',
                    Icons.view_kanban,
                    Colors.orangeAccent,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const KanbanScreen()))),
                const SizedBox(height: 10),
                _modulSatiri(
                    context,
                    'Planlama Takvimi',
                    'Tüm planları ajanda üzerinde görün',
                    Icons.school,
                    Colors.purpleAccent,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const AcademyCalendarScreen()))),
                const SizedBox(height: 10),
                _modulSatiri(
                    context,
                    'Teşkilat Birimleri',
                    'Birimleri görüntüleyin veya ekleyin',
                    Icons.group,
                    Colors.lightBlueAccent,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const UnitsScreen()))),
                const SizedBox(height: 10),
                _modulSatiri(
                    context,
                    'PDF Raporlar & Analiz',
                    'Tüm faaliyetleri PDF olarak indirin',
                    Icons.picture_as_pdf,
                    Colors.redAccent,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const PdfScreen()))),
                const SizedBox(height: 24),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Aktif Faaliyetler ve Planlar',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text('(${faaliyetler.length})',
                          style: const TextStyle(color: Colors.white70))
                    ]),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Tümü', 'Yapılacak', 'Yapılıyor', 'Tamamlandı']
                        .map((filtre) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filtre),
                          selected: secilenFiltre == filtre,
                          selectedColor: const Color(0xFF121816),
                          backgroundColor: const Color(0xFF1A2220),
                          labelStyle: TextStyle(
                              color: secilenFiltre == filtre
                                  ? Colors.white
                                  : Colors.white70),
                          onSelected: (bool selected) =>
                              setState(() => secilenFiltre = filtre),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                if (faaliyetler.isEmpty)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Kayıtlı faaliyet bulunamadı.',
                              style: TextStyle(color: Colors.white54))))
                else ...[
                  (() {
                    List<Map<String, dynamic>> filtrelenmis = faaliyetler;
                    if (secilenFiltre != 'Tümü')
                      filtrelenmis = faaliyetler
                          .where((f) => f['durum'] == secilenFiltre)
                          .toList();
                    if (filtrelenmis.isEmpty)
                      return const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                              child: Text('Gösterilecek faaliyet bulunamadı.',
                                  style: TextStyle(color: Colors.white54))));

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtrelenmis.length,
                      itemBuilder: (context, index) {
                        final f = filtrelenmis[index];
                        return Card(
                          color: const Color(0xFF1A2220),
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1))),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Chip(
                                        label: Text(f['durum'] ?? 'Yapılacak',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12)),
                                        backgroundColor:
                                            f['durum'] == 'Tamamlandı'
                                                ? Colors.green.shade800
                                                : (f['durum'] == 'Yapılıyor'
                                                    ? Colors.orange.shade800
                                                    : Colors.blue.shade800)),
                                    Row(
                                      children: [
                                        IconButton(
                                            icon: const Icon(Icons.edit,
                                                size: 20,
                                                color: Colors.blueAccent),
                                            onPressed: () =>
                                                _faaliyetEkleModalAc(
                                                    mevcutFaaliyet: f)),
                                        IconButton(
                                            icon: const Icon(Icons.delete,
                                                size: 20,
                                                color: Colors.redAccent),
                                            onPressed: () => _faaliyetSil(
                                                f['id'].toString())),
                                        IconButton(
                                            icon: const Icon(Icons.share,
                                                size: 20,
                                                color: Colors.white70),
                                            onPressed: () =>
                                                _whatsappOzetKopyala(
                                                    filtrelenmis)),
                                      ],
                                    ),
                                  ],
                                ),
                                Text(f['baslik'],
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                const SizedBox(height: 8),
                                Text('📅 Tarih: ${f['tarih']}',
                                    style:
                                        const TextStyle(color: Colors.white70)),
                                Text(
                                    '📌 Öncelik: ${f['oncelik']} \vert{} Birim:${f['hedef_birim']}',
                                    style:
                                        const TextStyle(color: Colors.white70)),
                                Text('👤 Sorumlu: ${f['olusturan_unvan']}',
                                    style:
                                        const TextStyle(color: Colors.white54)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }()),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _istatistikKolon(String baslik, String deger, Color renk) {
    return Column(children: [
      Text(deger,
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: renk)),
      const SizedBox(height: 4),
      Text(baslik, style: const TextStyle(fontSize: 12, color: Colors.white70))
    ]);
  }

  Widget _modulSatiri(BuildContext context, String baslik, String altBaslik,
      IconData ikon, Color renk, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF1A2220),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(ikon, color: renk, size: 26)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(baslik,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(altBaslik,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white54))
                ])),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
