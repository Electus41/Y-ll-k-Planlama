import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../core/notification_service.dart';
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

  InputDecoration _koyuInputDekorasyonu(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
      prefixIcon:
          Icon(icon, color: Colors.tealAccent.withValues(alpha: 0.7), size: 20),
      filled: true,
      fillColor: AppColors.inputFill,
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
      dropdownColor: AppColors.inputFill,
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.inputFill,
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
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Faaliyet silindi.'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _faaliyetEkleModalAc(
      {Map<String, dynamic>? mevcutFaaliyet}) async {
    List<Map<String, dynamic>> yoneticiler = [];
    Map<String, dynamic>? aktifKullanici;

    try {
      final profilData = await supabase
          .from('profiller')
          .select('id, ad, soyad, unvan')
          .order('ad');
      yoneticiler = List<Map<String, dynamic>>.from(profilData);

      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        aktifKullanici = yoneticiler.firstWhere(
            (y) => y['id'].toString() == currentUser.id,
            orElse: () => {'ad': 'Yönetici', 'soyad': '', 'unvan': ''});
      }
    } catch (e) {}

    if (!mounted) return;

    final baslikController =
        TextEditingController(text: mevcutFaaliyet?['baslik'] ?? '');

    bool aralikliTarih = mevcutFaaliyet != null &&
        mevcutFaaliyet['tarih'].toString().contains('-');

    DateTime sTarih = DateTime.now();
    String seciliGun = sTarih.day.toString();
    String seciliAy = aylar[sTarih.month - 1];
    String seciliYil = sTarih.year.toString();

    String bitisGun = seciliGun;
    String bitisAy = seciliAy;
    String bitisYil = seciliYil;

    if (mevcutFaaliyet != null && mevcutFaaliyet['tarih'] != null) {
      String tamTarih = mevcutFaaliyet['tarih'].toString();
      try {
        if (tamTarih.contains('-')) {
          var parcalar = tamTarih.split('-');
          var bas = parcalar[0].trim().split(' ');
          var bit = parcalar[1].trim().split(' ');
          if (bas.length == 3) {
            seciliGun = bas[0];
            seciliAy = bas[1];
            seciliYil = bas[2];
          }
          if (bit.length == 3) {
            bitisGun = bit[0];
            bitisAy = bit[1];
            bitisYil = bit[2];
          }
        } else {
          var bas = tamTarih.split(' ');
          if (bas.length == 3) {
            seciliGun = bas[0];
            seciliAy = bas[1];
            seciliYil = bas[2];
          }
        }
      } catch (_) {}
    }

    if (!['2026', '2027', '2028', '2029', '2030'].contains(seciliYil))
      seciliYil = '2026';
    if (!['2026', '2027', '2028', '2029', '2030'].contains(bitisYil))
      bitisYil = '2026';

    String durum = mevcutFaaliyet?['durum'] ?? 'Yapılacak';
    String oncelik = mevcutFaaliyet?['oncelik'] ?? 'Normal';
    String? seciliKisiId = mevcutFaaliyet?['atanan_kisi_id']?.toString();

    if (yoneticiler.isNotEmpty) {
      final idListesi = yoneticiler.map((y) => y['id'].toString()).toList();
      if (seciliKisiId == null || !idListesi.contains(seciliKisiId)) {
        seciliKisiId = idListesi.first;
      }
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
                        isUpdate ? 'Faaliyeti Düzenle' : 'Yeni Faaliyet Ekle',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
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
                      label: 'Faaliyet Adı', icon: Icons.description),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Tarih Aralığı Seç',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text(
                      'Birden fazla gün sürecek faaliyetler için açın',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: aralikliTarih,
                  activeColor: AppColors.accent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setModalState(() {
                      aralikliTarih = val;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                    aralikliTarih
                        ? 'Başlangıç Tarihi:'
                        : 'Faaliyet / İşlem Tarihi:',
                    style: const TextStyle(
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
                if (aralikliTarih) ...[
                  const SizedBox(height: 16),
                  const Text('Bitiş Tarihi:',
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
                              value: bitisGun,
                              items:
                                  List.generate(31, (i) => (i + 1).toString()),
                              onChanged: (val) =>
                                  setModalState(() => bitisGun = val!))),
                      const SizedBox(width: 8),
                      Expanded(
                          flex: 3,
                          child: _tarihDropdown(
                              value: bitisAy,
                              items: aylar,
                              onChanged: (val) =>
                                  setModalState(() => bitisAy = val!))),
                      const SizedBox(width: 8),
                      Expanded(
                          flex: 2,
                          child: _tarihDropdown(
                              value: bitisYil,
                              items: ['2026', '2027', '2028', '2029', '2030'],
                              onChanged: (val) =>
                                  setModalState(() => bitisYil = val!))),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (yoneticiler.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: seciliKisiId,
                    isExpanded: true,
                    items: yoneticiler.map((y) {
                      final adSoyad =
                          '${y['ad'] ?? ''} ${y['soyad'] ?? ''}'.trim();
                      final unvan = (y['unvan'] ?? '').toString().trim();
                      final etiket =
                          unvan.isNotEmpty ? '$adSoyad ($unvan)' : adSoyad;
                      return DropdownMenuItem<String>(
                        value: y['id'].toString(),
                        child: Text(etiket.isEmpty ? 'Yönetici' : etiket,
                            overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => seciliKisiId = val),
                    dropdownColor: AppColors.inputFill,
                    style: const TextStyle(color: Colors.white),
                    decoration: _koyuInputDekorasyonu(
                        label: 'Görev Atanan Yönetici (Bildirim Gider)',
                        icon: Icons.person_pin_circle),
                  ),
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
                        onChanged: (val) => setModalState(() => durum = val!),
                        dropdownColor: AppColors.inputFill,
                        style: const TextStyle(color: Colors.white),
                        decoration: _koyuInputDekorasyonu(
                            label: 'Durum', icon: Icons.stacked_bar_chart),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: oncelik,
                        items: ['Acil', 'Normal', 'Düşük']
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) => setModalState(() => oncelik = val!),
                        dropdownColor: AppColors.inputFill,
                        style: const TextStyle(color: Colors.white),
                        decoration: _koyuInputDekorasyonu(
                            label: 'Öncelik', icon: Icons.flag),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (baslikController.text.trim().isEmpty) return;

                    String tarihStr = '$seciliGun $seciliAy $seciliYil';
                    if (aralikliTarih) {
                      tarihStr += ' - $bitisGun $bitisAy $bitisYil';
                    }

                    String sorumluEtiketi = 'Bilinmiyor';
                    if (seciliKisiId != null && yoneticiler.isNotEmpty) {
                      final secilen = yoneticiler.firstWhere(
                          (y) => y['id'].toString() == seciliKisiId,
                          orElse: () => yoneticiler.first);
                      final adSoyad =
                          '${secilen['ad'] ?? ''} ${secilen['soyad'] ?? ''}'
                              .trim();
                      final unvan = (secilen['unvan'] ?? '').toString().trim();
                      sorumluEtiketi =
                          unvan.isNotEmpty ? '$adSoyad ($unvan)' : adSoyad;
                    }

                    String atayanEtiketi = 'Sistem';
                    if (aktifKullanici != null) {
                      final adSoyad =
                          '${aktifKullanici['ad'] ?? ''} ${aktifKullanici['soyad'] ?? ''}'
                              .trim();
                      final unvan =
                          (aktifKullanici['unvan'] ?? '').toString().trim();
                      atayanEtiketi =
                          unvan.isNotEmpty ? '$adSoyad ($unvan)' : adSoyad;
                    }

                    final Map<String, dynamic> kayitVerisi = {
                      'baslik': baslikController.text.trim(),
                      'tarih': tarihStr,
                      'durum': durum,
                      'oncelik': oncelik,
                      'hedef_birim': sorumluEtiketi,
                      'olusturan_unvan': atayanEtiketi,
                      'atanan_kisi_id': seciliKisiId,
                    };

                    if (isUpdate) {
                      await supabase
                          .from('faaliyetler')
                          .update(kayitVerisi)
                          .eq('id', mevcutFaaliyet['id']);
                    } else {
                      kayitVerisi['kategori'] = 'Genel';
                      await supabase.from('faaliyetler').insert(kayitVerisi);
                    }

                    if (seciliKisiId != null) {
                      await NotificationService.gorevBildirimiGonder(
                        hedefKullaniciId: seciliKisiId!,
                        faaliyetBaslik: baslikController.text.trim(),
                        tarih: tarihStr,
                        birim: 'Yeni Görev',
                      );
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    setState(() {});
                  },
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('Kaydet ve Bildir',
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
    for (var f in faaliyetler) {
      metin +=
          "🔹 *${f['baslik']}*\n📅 ${f['tarih']}\n📌 Durum: ${f['durum']}\n🎯 Sorumlu: ${f['hedef_birim']}\n👤 Atayan: ${f['olusturan_unvan']}\n\n";
    }
    Clipboard.setData(ClipboardData(text: metin));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp özeti panoya kopyalandı!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      blurRadius: 8),
                ],
              ),
              child: Image.asset('assets/images/logo.png', height: 28),
            ),
            const SizedBox(width: 12),
            const Text('Kocaeli Genç İHH',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: AppColors.accent),
            tooltip: 'Profilim',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const ProfileScreen())),
          ),
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
                child: CircularProgressIndicator(color: AppColors.accent));
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
                        colors: [AppColors.background, AppColors.card],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 2)
                    ],
                  ),
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
                    'Planlanan yeni bir etkinlik tanımlayın ve görev atayın',
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
                    'Tüm planları ajanda üzerinde görün ve ekleyin',
                    Icons.calendar_month,
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
                    'Birimleri ekleyin, düzenleyin veya silin',
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
                    'Tüm faaliyetleri kurumsal PDF olarak indirin',
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
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
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
                          selectedColor: AppColors.background,
                          backgroundColor: AppColors.card,
                          labelStyle: TextStyle(
                              color: secilenFiltre == filtre
                                  ? AppColors.accent
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
                          color: AppColors.card,
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
                                                  : Colors.blue.shade800),
                                    ),
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
                                                _whatsappOzetKopyala([f])),
                                      ],
                                    ),
                                  ],
                                ),
                                Text(f['baslik'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                const SizedBox(height: 8),
                                Text('📅 Tarih: ${f['tarih'] ?? '-'}',
                                    style:
                                        const TextStyle(color: Colors.white70)),
                                Text(
                                    '📌 Öncelik: ${f['oncelik'] ?? 'Normal'} | 🎯 Sorumlu: ${f['hedef_birim'] ?? '-'}',
                                    style:
                                        const TextStyle(color: Colors.white70)),
                                Text(
                                    '👤 Atayan: ${f['olusturan_unvan'] ?? '-'}',
                                    style: const TextStyle(
                                        color: AppColors.accent, fontSize: 13)),
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
            color: AppColors.card,
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
