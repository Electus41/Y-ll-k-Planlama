import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/notification_service.dart';

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  String _kullaniciRol = 'Gönüllü';
  String _kullaniciBirim = '';
  bool _isAdmin = false;
  bool _yetkilerYuklendi = false;

  // Komisyon Filtresi
  String _seciliKomisyon = 'Tümü';
  final List<String> _komisyonFiltreleri = [
    'Tümü',
    'İlkokul Komisyonu',
    'Ortaokul Komisyonu',
    'Lise Komisyonu',
    'Üniversite Komisyonu',
    'Genel'
  ];

  @override
  void initState() {
    super.initState();
    _kullaniciYetkileriniGetir();
  }

  Future<void> _kullaniciYetkileriniGetir() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final data = await Supabase.instance.client
          .from('profiller')
          .select('yetki_seviyesi, bagli_birim, unvan')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _kullaniciRol = data['yetki_seviyesi'] ?? 'Gönüllü';
          _kullaniciBirim = data['bagli_birim'] ?? '';
          final unvan = data['unvan'] ?? '';
          _isAdmin =
              (unvan == 'İl Başkanı' || unvan == 'Teşkilatlanma Başkanı');
          _yetkilerYuklendi = true;
        });
      }
    }
  }

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

  Future<void> _durumGuncelle(
      String id, String yeniDurum, String olusturanBirim) async {
    if (!_isAdmin && olusturanBirim != _kullaniciBirim) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Sadece kendi biriminize ait görevleri taşıyabilirsiniz!'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    await Supabase.instance.client
        .from('faaliyetler')
        .update({'durum': yeniDurum}).eq('id', id);
  }

  Future<void> _gorevSil(String id) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF161C1A),
            title:
                const Text('Görevi Sil', style: TextStyle(color: Colors.white)),
            content: const Text('Bu görevi silmek istediğinize emin misiniz?',
                style: TextStyle(color: Colors.white70)),
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
      await Supabase.instance.client.from('faaliyetler').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Görev silindi.', style: TextStyle(color: Colors.white))));
      }
    }
  }

  // HATALI OLAN "ALT GÖREV EKLEME MODALI" TAMAMEN DÜZELTİLDİ
  Future<void> _kanbandanAltGorevEkleAc(
      {Map<String, dynamic>? mevcutGorev}) async {
    if (_kullaniciRol == 'Gönüllü') return;

    List<Map<String, dynamic>> yoneticiler = [];
    List<Map<String, dynamic>> anaFaaliyetler = [];
    Map<String, dynamic>? aktifKullanici;

    try {
      // Yöneticileri Çek - 'eq(aktif, true)' BURADAN KALDIRILDI Kİ HATA VERMESİN
      final profilData = await Supabase.instance.client
          .from('profiller')
          .select('id, ad, soyad, unvan')
          .order('ad');
      yoneticiler = List<Map<String, dynamic>>.from(profilData);

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        aktifKullanici = yoneticiler.firstWhere(
            (y) => y['id'].toString() == currentUser.id,
            orElse: () => {'ad': 'Yönetici', 'soyad': '', 'unvan': ''});
      }

      // Ana Faaliyetleri Çek (Null filtresini Supabase'de değil Dart tarafında yapıyoruz ki %100 çalışsın)
      final faaliyetData = await Supabase.instance.client
          .from('faaliyetler')
          .select('id, baslik, hedef_birim, hedef_birim_id, bagli_faaliyet_id')
          .order('created_at', ascending: false);

      // Sadece ana faaliyetleri (Alt görev olmayanları) filtrele
      anaFaaliyetler = List<Map<String, dynamic>>.from(faaliyetData)
          .where((f) => f['bagli_faaliyet_id'] == null)
          .toList();
    } catch (e) {
      debugPrint("Veri Çekme Hatası: $e");
    }

    if (!mounted) return;

    if (anaFaaliyetler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Önce takvimden ana bir faaliyet eklemelisiniz!'),
          backgroundColor: Colors.orange));
      return;
    }

    final baslikController =
        TextEditingController(text: mevcutGorev?['baslik'] ?? '');
    String? seciliAnaFaaliyetId =
        mevcutGorev?['bagli_faaliyet_id']?.toString() ??
            anaFaaliyetler.first['id'].toString();
    String? seciliKisiId = mevcutGorev?['atanan_kisi_id']?.toString();
    String durum = mevcutGorev?['durum'] ?? 'Yapılacak';
    String oncelik = mevcutGorev?['oncelik'] ?? 'Normal';

    // Alt görev tarihi tek bir gün (Teslim tarihi)
    DateTime teslimTarihi = mevcutGorev != null && mevcutGorev['tarih'] != null
        ? (DateTime.tryParse(mevcutGorev['tarih']
                .toString()
                .split(' ')
                .first
                .replaceAll('.', '-')) ??
            DateTime.now())
        : DateTime.now();

    bool isUpdate = mevcutGorev != null;

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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        isUpdate
                            ? 'Alt Görevi Düzenle'
                            : 'Yeni Alt Görev Ataması',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),

                // Hangi Ana Faaliyete Bağlı?
                DropdownButtonFormField<String>(
                  value: seciliAnaFaaliyetId,
                  isExpanded: true,
                  items: anaFaaliyetler
                      .map((f) => DropdownMenuItem<String>(
                          value: f['id'].toString(),
                          child: Text(f['baslik'],
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) =>
                      setModalState(() => seciliAnaFaaliyetId = val),
                  dropdownColor: AppColors.inputFill,
                  style: const TextStyle(color: Colors.white),
                  decoration: _koyuInputDekorasyonu(
                      label: 'Bağlı Olduğu Ana Faaliyet (Örn: Kış Kampı)',
                      icon: Icons.merge_type),
                ),
                const SizedBox(height: 16),

                TextField(
                    controller: baslikController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _koyuInputDekorasyonu(
                        label: 'Alt Görev Adı (Örn: Otobüs Ayarlanacak)',
                        icon: Icons.task_alt)),
                const SizedBox(height: 16),

                if (yoneticiler.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: seciliKisiId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Henüz Atanmadı')),
                      ...yoneticiler.map((y) {
                        final adSoyad =
                            '${y['ad'] ?? ''} ${y['soyad'] ?? ''}'.trim();
                        final unvan = (y['unvan'] ?? '').toString().trim();
                        final etiket =
                            unvan.isNotEmpty ? '$adSoyad ($unvan)' : adSoyad;
                        return DropdownMenuItem<String>(
                            value: y['id'].toString(),
                            child: Text(etiket.isEmpty ? 'Yönetici' : etiket,
                                overflow: TextOverflow.ellipsis));
                      }),
                    ],
                    onChanged: (val) => setModalState(() => seciliKisiId = val),
                    dropdownColor: AppColors.inputFill,
                    style: const TextStyle(color: Colors.white),
                    decoration: _koyuInputDekorasyonu(
                        label: 'Görevi Yapacak Kişi (Bildirim Gider)',
                        icon: Icons.person_pin_circle),
                  ),

                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Son Teslim / Bitiş Tarihi',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                  subtitle: Text(
                      '${teslimTarihi.day}.${teslimTarihi.month}.${teslimTarihi.year}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  trailing:
                      const Icon(Icons.calendar_month, color: AppColors.accent),
                  onTap: () async {
                    final secilen = await showDatePicker(
                      context: context,
                      initialDate: teslimTarihi,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030),
                      builder: (context, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                              primary: AppColors.accent,
                              onPrimary: Colors.black,
                              surface: Color(0xFF161C1A)),
                        ),
                        child: child!,
                      ),
                    );
                    if (secilen != null)
                      setModalState(() => teslimTarihi = secilen);
                  },
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

                    // Ana faaliyetin bilgilerini bul ki alt görev de o komisyona ait olsun
                    final seciliAnaFaaliyet = anaFaaliyetler.firstWhere(
                        (f) => f['id'].toString() == seciliAnaFaaliyetId);

                    final atayanAdSoyad =
                        '${aktifKullanici?['ad'] ?? ''} ${aktifKullanici?['soyad'] ?? ''}'
                            .trim();
                    final atayanUnvan = aktifKullanici?['unvan'] ?? '';
                    final atayanTamAd = atayanUnvan.isNotEmpty
                        ? '$atayanAdSoyad ($atayanUnvan)'
                        : atayanAdSoyad;

                    String sorumluKisiAd = '';
                    if (seciliKisiId != null) {
                      final secilen = yoneticiler.firstWhere(
                          (y) => y['id'].toString() == seciliKisiId,
                          orElse: () => yoneticiler.first);
                      sorumluKisiAd =
                          '${secilen['ad'] ?? ''} ${secilen['soyad'] ?? ''}'
                              .trim();
                    }

                    final Map<String, dynamic> kayitVerisi = {
                      'baslik': baslikController.text.trim(),
                      'tarih':
                          '${teslimTarihi.day}.${teslimTarihi.month}.${teslimTarihi.year}',
                      'durum': durum,
                      'oncelik': oncelik,
                      'atanan_kisi_id': seciliKisiId,
                      'sorumlu_kisi_ad': sorumluKisiAd,
                      'atayan_ad': atayanTamAd,
                      'bagli_faaliyet_id': seciliAnaFaaliyet['id'],
                      'bagli_faaliyet_baslik': seciliAnaFaaliyet['baslik'],
                      // Alt görev, ana görevin komisyonuna otomatik atanır
                      'hedef_birim_id': seciliAnaFaaliyet['hedef_birim_id'],
                      'hedef_birim': seciliAnaFaaliyet['hedef_birim'],
                      'olusturan_unvan': atayanUnvan, // Sorumlu birim
                      'kategori': 'Alt Görev',
                    };

                    if (isUpdate) {
                      await Supabase.instance.client
                          .from('faaliyetler')
                          .update(kayitVerisi)
                          .eq('id', mevcutGorev['id']);
                    } else {
                      await Supabase.instance.client
                          .from('faaliyetler')
                          .insert(kayitVerisi);
                    }

                    if (seciliKisiId != null && !isUpdate) {
                      await NotificationService.gorevBildirimiGonder(
                        hedefKullaniciId: seciliKisiId!,
                        faaliyetBaslik: baslikController.text.trim(),
                        tarih:
                            '${teslimTarihi.day}.${teslimTarihi.month}.${teslimTarihi.year}',
                        birim: 'Yeni Alt Görev Eklendi',
                      );
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    setState(() {});
                  },
                  icon: const Icon(Icons.check, size: 20),
                  label: Text(isUpdate ? 'Güncelle' : 'Alt Görevi Ata',
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

  Widget _kanbanKarti(Map<String, dynamic> isItem) {
    final bool tamYetkili =
        _isAdmin || isItem['olusturan_unvan'] == _kullaniciBirim;
    final bool isAltGorev = isItem['bagli_faaliyet_baslik'] != null;

    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
              color: isAltGorev
                  ? Colors.tealAccent.withValues(alpha: 0.3)
                  : Colors.white12,
              width: isAltGorev ? 1.5 : 1.0)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAltGorev)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                    '🔗 Ana Etkinlik: ${isItem['bagli_faaliyet_baslik']}',
                    style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: Text(isItem['baslik'] ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14))),
                if (tamYetkili)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                          onTap: () =>
                              _kanbandanAltGorevEkleAc(mevcutGorev: isItem),
                          child: const Icon(Icons.edit,
                              size: 18, color: Colors.blueAccent)),
                      const SizedBox(width: 8),
                      GestureDetector(
                          onTap: () => _gorevSil(isItem['id'].toString()),
                          child: const Icon(Icons.delete,
                              size: 18, color: Colors.redAccent)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('⏰ Teslim: ${isItem['tarih'] ?? '-'}',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            if (isItem['sorumlu_kisi_ad'] != null &&
                isItem['sorumlu_kisi_ad'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('👤 Atanan: ${isItem['sorumlu_kisi_ad']}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 4),
            Text('🎯 Hedef Komisyon: ${isItem['hedef_birim'] ?? 'Genel'}',
                style:
                    const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _sutunOlustur(String baslik, String dbDurum,
      List<Map<String, dynamic>> isler, Color renk) {
    return Container(
      width: 290,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: DragTarget<Map<String, dynamic>>(
        onAcceptWithDetails: (details) {
          final data = details.data;
          if (data['durum'] != dbDurum) {
            _durumGuncelle(
                data['id'].toString(), dbDurum, data['olusturan_unvan'] ?? '');
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            decoration: BoxDecoration(
              color: candidateData.isNotEmpty
                  ? renk.withOpacity(0.1)
                  : AppColors.background.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: candidateData.isNotEmpty
                  ? Border.all(color: renk, width: 2)
                  : null,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: renk.withOpacity(0.2),
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
                    itemBuilder: (context, index) {
                      final isItem = isler[index];
                      final bool tamYetkili = _isAdmin ||
                          isItem['olusturan_unvan'] == _kullaniciBirim;
                      if (!tamYetkili) return _kanbanKarti(isItem);

                      return Draggable<Map<String, dynamic>>(
                        data: isItem,
                        feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                                width: 280, child: _kanbanKarti(isItem))),
                        childWhenDragging:
                            Opacity(opacity: 0.3, child: _kanbanKarti(isItem)),
                        child: _kanbanKarti(isItem),
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
    if (!_yetkilerYuklendi) {
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
      floatingActionButton: _kullaniciRol == 'Gönüllü'
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              onPressed: () => _kanbandanAltGorevEkleAc(),
              icon: const Icon(Icons.add_task, color: Colors.black),
              label: const Text('Alt Görev Ata',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
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
                children: _komisyonFiltreleri.map((komisyon) {
                  final isSelected = _seciliKomisyon == komisyon;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(komisyon),
                      selected: isSelected,
                      onSelected: (val) =>
                          setState(() => _seciliKomisyon = komisyon),
                      backgroundColor: Colors.transparent,
                      selectedColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.white24)),
                      labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('faaliyetler')
                  .stream(primaryKey: ['id'])
                  .order('created_at', ascending: false)
                  .map((maps) => List<Map<String, dynamic>>.from(maps)),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent));
                }

                List<Map<String, dynamic>> tumGorevler =
                    snapshot.hasData ? snapshot.data! : [];

                if (_seciliKomisyon != 'Tümü') {
                  tumGorevler = tumGorevler
                      .where((f) => f['hedef_birim'] == _seciliKomisyon)
                      .toList();
                }

                final yapilacak = tumGorevler
                    .where((f) => f['durum'] == 'Yapılacak')
                    .toList();
                final yapiliyor = tumGorevler
                    .where((f) => f['durum'] == 'Yapılıyor')
                    .toList();
                final tamamlandi = tumGorevler
                    .where((f) => f['durum'] == 'Tamamlandı')
                    .toList();

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _sutunOlustur('Yapılacak', 'Yapılacak', yapilacak,
                            Colors.lightBlueAccent),
                        _sutunOlustur('Yapılıyor', 'Yapılıyor', yapiliyor,
                            Colors.orangeAccent),
                        _sutunOlustur('Tamamlandı', 'Tamamlandı', tamamlandi,
                            Colors.greenAccent),
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
