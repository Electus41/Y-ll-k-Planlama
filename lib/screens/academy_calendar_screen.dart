import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/notification_service.dart';

class AcademyCalendarScreen extends StatefulWidget {
  const AcademyCalendarScreen({super.key});

  @override
  State<AcademyCalendarScreen> createState() => _AcademyCalendarScreenState();
}

class _AcademyCalendarScreenState extends State<AcademyCalendarScreen> {
  String seciliAyFiltresi = 'Tümü';
  String seciliYilFiltresi = '2026';

  // YENİ: Komisyon Filtresi
  String _seciliKomisyon = 'Tümü';
  final List<String> _komisyonFiltreleri = [
    'Tümü',
    'İlkokul Komisyonu',
    'Ortaokul Komisyonu',
    'Lise Komisyonu',
    'Üniversite Komisyonu',
    'Genel'
  ];

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

  @override
  void initState() {
    super.initState();
    seciliAyFiltresi = aylar[DateTime.now().month - 1];
    seciliYilFiltresi = DateTime.now().year.toString();
    if (!['2026', '2027', '2028', '2029', '2030'].contains(seciliYilFiltresi)) {
      seciliYilFiltresi = '2026';
    }
  }

  InputDecoration _koyuInputDekorasyonu(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
      prefixIcon:
          Icon(icon, color: Colors.tealAccent.withOpacity(0.7), size: 20),
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
      await Supabase.instance.client.from('faaliyetler').delete().eq('id', id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Plan takvimden silindi.'),
            backgroundColor: Colors.red));
      }
    }
  }

  // ANA EKRANIN AYNISI (Yetki ve Sorumlu mantığı ile tam senkronize)
  Future<void> _planEkleModalAc({Map<String, dynamic>? mevcutFaaliyet}) async {
    List<Map<String, dynamic>> yoneticiler = [];
    List<Map<String, dynamic>> tumBirimler = [];
    Map<String, dynamic>? aktifKullanici;

    try {
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
      final birimData = await Supabase.instance.client
          .from('birimler')
          .select('id, ad, kategori')
          .order('sira');
      tumBirimler = List<Map<String, dynamic>>.from(birimData);
    } catch (e) {}

    if (!mounted) return;

    bool isAdmin = (aktifKullanici?['unvan'] == 'İl Başkanı' ||
        aktifKullanici?['unvan'] == 'Teşkilatlanma Başkanı');
    String? kullaniciUnvani = aktifKullanici?['unvan'];

    final baslikController =
        TextEditingController(text: mevcutFaaliyet?['baslik'] ?? '');
    bool aralikliTarih = mevcutFaaliyet != null &&
        mevcutFaaliyet['tarih'].toString().contains('-');

    DateTime sTarih = DateTime.now();
    String seciliGun = sTarih.day.toString();
    String seciliAy = aylar[sTarih.month - 1];
    String seciliYil = sTarih.year.toString();
    String bitisGun = seciliGun, bitisAy = seciliAy, bitisYil = seciliYil;

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
    String? seciliHedefId = mevcutFaaliyet?['hedef_birim_id'];
    String? seciliHedefAd = mevcutFaaliyet?['hedef_birim'];
    String? seciliSorumluId = mevcutFaaliyet?['sorumlu_birim_id'];
    String? seciliSorumluAd = mevcutFaaliyet?['olusturan_unvan'];

    if (!isAdmin && seciliSorumluId == null && kullaniciUnvani != null) {
      final b =
          tumBirimler.where((x) => x['ad'] == kullaniciUnvani).firstOrNull;
      if (b != null) {
        seciliSorumluId = b['id'];
        seciliSorumluAd = b['ad'];
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isUpdate ? 'Planı Düzenle' : 'Yeni Plan Ekle',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                    controller: baslikController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _koyuInputDekorasyonu(
                        label: 'Plan / Kamp / Etkinlik Adı',
                        icon: Icons.description)),
                const SizedBox(height: 16),
                if (isAdmin)
                  DropdownButtonFormField<String>(
                    value: seciliSorumluId,
                    items: tumBirimler
                        .map((b) => DropdownMenuItem<String>(
                            value: b['id'],
                            child:
                                Text(b['ad'], overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) {
                      setModalState(() {
                        seciliSorumluId = val;
                        seciliSorumluAd =
                            tumBirimler.firstWhere((b) => b['id'] == val)['ad'];
                      });
                    },
                    dropdownColor: AppColors.inputFill,
                    style: const TextStyle(color: Colors.white),
                    decoration: _koyuInputDekorasyonu(
                        label: 'Sorumlu Birim (Görevlendirilen)',
                        icon: Icons.account_balance),
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
                            color: Colors.tealAccent.withOpacity(0.7),
                            size: 20),
                        const SizedBox(width: 16),
                        Text(
                            'Sorumlu Birim: ${seciliSorumluAd ?? 'Belirtilmedi'}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (yoneticiler.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: seciliKisiId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Kişi Seçilmedi (Tüm Birim Sorumlu)')),
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
                        label: 'Özel Sorumlu Kişi (Opsiyonel)',
                        icon: Icons.person_pin_circle),
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: seciliHedefId,
                  items: tumBirimler
                      .where((b) => b['kategori'] == 'Hedef Kitle Komisyonu')
                      .map((b) => DropdownMenuItem<String>(
                          value: b['id'],
                          child:
                              Text(b['ad'], overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) {
                    setModalState(() {
                      seciliHedefId = val;
                      seciliHedefAd =
                          tumBirimler.firstWhere((b) => b['id'] == val)['ad'];
                    });
                  },
                  dropdownColor: AppColors.inputFill,
                  style: const TextStyle(color: Colors.white),
                  decoration: _koyuInputDekorasyonu(
                      label: 'Faaliyet Alanı / Hedef Komisyon',
                      icon: Icons.groups),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Tarih Aralığı Seç (Kamp, Sınav vb.)',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: aralikliTarih,
                  activeColor: AppColors.accent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setModalState(() => aralikliTarih = val),
                ),
                const SizedBox(height: 8),
                Text(aralikliTarih ? 'Başlangıç Tarihi:' : 'Faaliyet Tarihi:',
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
                DropdownButtonFormField<String>(
                  value: durum,
                  items: ['Yapılacak', 'Yapılıyor', 'Tamamlandı']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setModalState(() => durum = val!),
                  dropdownColor: AppColors.inputFill,
                  style: const TextStyle(color: Colors.white),
                  decoration: _koyuInputDekorasyonu(
                      label: 'Süreç / Kanban Durumu',
                      icon: Icons.stacked_bar_chart),
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
                    if (seciliHedefId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Lütfen Hedef Komisyon seçiniz!'),
                          backgroundColor: Colors.orange));
                      return;
                    }

                    String tarihStr = '$seciliGun $seciliAy $seciliYil';
                    if (aralikliTarih)
                      tarihStr += ' - $bitisGun $bitisAy $bitisYil';

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
                      'tarih': tarihStr,
                      'durum': durum,
                      'oncelik': oncelik,
                      'atanan_kisi_id': seciliKisiId,
                      'sorumlu_kisi_ad': sorumluKisiAd,
                      'atayan_ad': atayanTamAd,
                      'hedef_birim_id': seciliHedefId,
                      'hedef_birim': seciliHedefAd,
                      'sorumlu_birim_id': seciliSorumluId,
                      'olusturan_unvan': seciliSorumluAd,
                    };

                    if (isUpdate) {
                      await Supabase.instance.client
                          .from('faaliyetler')
                          .update(kayitVerisi)
                          .eq('id', mevcutFaaliyet['id']);
                    } else {
                      kayitVerisi['kategori'] = 'Genel';
                      await Supabase.instance.client
                          .from('faaliyetler')
                          .insert(kayitVerisi);
                    }

                    if (seciliKisiId != null && !isUpdate) {
                      await NotificationService.gorevBildirimiGonder(
                        hedefKullaniciId: seciliKisiId!,
                        faaliyetBaslik: baslikController.text.trim(),
                        tarih: tarihStr,
                        birim: 'Yeni Plan & Görev Eklendi',
                      );
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    setState(() {});
                  },
                  icon: const Icon(Icons.check, size: 20),
                  label: Text(isUpdate ? 'Güncelle' : 'Kaydet ve Ekle',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Yıllık Planlama Takvimi',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          DropdownButton<String>(
            value: seciliYilFiltresi,
            dropdownColor: AppColors.card,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            items: ['2026', '2027', '2028', '2029', '2030']
                .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => seciliYilFiltresi = val);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        onPressed: () => _planEkleModalAc(),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Plan Ekle',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.background,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                // 1. Ay Filtresi
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: ['Tümü', ...aylar].map((ay) {
                      final isSelected = seciliAyFiltresi == ay;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(ay),
                          selected: isSelected,
                          onSelected: (val) =>
                              setState(() => seciliAyFiltresi = ay),
                          backgroundColor: Colors.transparent,
                          selectedColor: AppColors.accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.white24)),
                          labelStyle: TextStyle(
                              color: isSelected ? Colors.black : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // YENİ: 2. Komisyon Filtresi
                SingleChildScrollView(
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
                          selectedColor: AppColors.card,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.white24)),
                          labelStyle: TextStyle(
                              color: isSelected
                                  ? AppColors.accent
                                  : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
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

                final tumFaaliyetler = snapshot.hasData
                    ? snapshot.data!
                    : <Map<String, dynamic>>[];

                final filtrelenmis = tumFaaliyetler.where((f) {
                  final tarih = (f['tarih'] ?? '').toString();
                  if (!tarih.contains(seciliYilFiltresi)) return false;
                  if (seciliAyFiltresi != 'Tümü' &&
                      !tarih.contains(seciliAyFiltresi)) return false;

                  // Hedef Komisyon Filtresini Uygula
                  if (_seciliKomisyon != 'Tümü' &&
                      f['hedef_birim'] != _seciliKomisyon) return false;

                  return true;
                }).toList();

                if (filtrelenmis.isEmpty) {
                  return const Center(
                      child: Text('Bu döneme ait plan bulunmuyor.',
                          style: TextStyle(color: Colors.white54)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtrelenmis.length,
                  itemBuilder: (context, index) {
                    final f = filtrelenmis[index];

                    String gunGosterimi = '';
                    String tamTarih = f['tarih']?.toString() ?? '';
                    if (tamTarih.contains('-')) {
                      var parcalar = tamTarih.split('-');
                      var baslangicGun =
                          parcalar[0].trim().split(' ').isNotEmpty
                              ? parcalar[0].trim().split(' ')[0]
                              : '';
                      var bitisGun = parcalar[1].trim().split(' ').isNotEmpty
                          ? parcalar[1].trim().split(' ')[0]
                          : '';
                      gunGosterimi = '$baslangicGun-$bitisGun';
                    } else {
                      var parcalar = tamTarih.split(' ');
                      gunGosterimi = parcalar.isNotEmpty ? parcalar[0] : '';
                    }

                    return Card(
                      color: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white12)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.2),
                                  shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text(gunGosterimi,
                                  style: const TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                  textAlign: TextAlign.center),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f['baslik'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(
                                      '🏢 Sorumlu: ${f['olusturan_unvan'] ?? 'Belirtilmedi'}',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12)),
                                  if (f['sorumlu_kisi_ad'] != null &&
                                      f['sorumlu_kisi_ad']
                                          .toString()
                                          .isNotEmpty)
                                    Text('👤 Kişi: ${f['sorumlu_kisi_ad']}',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                  Text(
                                      '🎯 Hedef: ${f['hedef_birim'] ?? 'Genel'}',
                                      style: const TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
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
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(f['durum'] ?? 'Yapılacak',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 11)),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          size: 20, color: Colors.blueAccent),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      onPressed: () =>
                                          _planEkleModalAc(mevcutFaaliyet: f),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          size: 20, color: Colors.redAccent),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      onPressed: () =>
                                          _faaliyetSil(f['id'].toString()),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          ],
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
