import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/notification_service.dart';

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
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

  Future<void> _durumGuncelle(String id, String yeniDurum) async {
    await supabase
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
      await supabase.from('faaliyetler').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Görev silindi.', style: TextStyle(color: Colors.white))));
      }
    }
  }

  Future<void> _kanbandanGorevEkleAc(
      {Map<String, dynamic>? mevcutGorev}) async {
    List<Map<String, dynamic>> yoneticiler = [];
    List<Map<String, dynamic>> mevcutFaaliyetler = [];
    Map<String, dynamic>? aktifKullanici;

    try {
      final profilData = await supabase
          .from('profiller')
          .select('id, ad, soyad, unvan')
          .order('ad');
      yoneticiler = List<Map<String, dynamic>>.from(profilData);

      final faaliyetData = await supabase
          .from('faaliyetler')
          .select('id, baslik, tarih')
          .order('created_at', ascending: false)
          .limit(30);
      mevcutFaaliyetler = List<Map<String, dynamic>>.from(faaliyetData);

      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        aktifKullanici = yoneticiler.firstWhere(
            (y) => y['id'].toString() == currentUser.id,
            orElse: () => {'ad': 'Yönetici', 'soyad': '', 'unvan': ''});
      }
    } catch (e) {}

    if (!mounted) return;

    if (mevcutFaaliyetler.isEmpty && mevcutGorev == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Önce takvime bir faaliyet/kamp eklemelisiniz.')));
      return;
    }

    final baslikController =
        TextEditingController(text: mevcutGorev?['baslik'] ?? '');
    String durum = mevcutGorev?['durum'] ?? 'Yapılacak';
    String? seciliKisiId = mevcutGorev?['atanan_kisi_id']?.toString() ??
        (yoneticiler.isNotEmpty ? yoneticiler.first['id'].toString() : null);

    String? seciliFaaliyetTarihi = mevcutGorev?['tarih']?.toString();
    String? seciliFaaliyetBaslik = mevcutGorev?['kategori']?.toString() ??
        (mevcutFaaliyetler.isNotEmpty
            ? mevcutFaaliyetler.first['baslik'].toString()
            : null);

    if (mevcutGorev == null && mevcutFaaliyetler.isNotEmpty) {
      seciliFaaliyetTarihi = mevcutFaaliyetler.first['tarih'].toString();
    }

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
                    Text(isUpdate ? 'Görevi Düzenle' : 'Alt Görev Ekle & Ata',
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
                if (!isUpdate && mevcutFaaliyetler.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: seciliFaaliyetBaslik,
                    isExpanded: true,
                    items: mevcutFaaliyetler.map((f) {
                      return DropdownMenuItem<String>(
                        value: f['baslik'].toString(),
                        child: Text('${f['baslik']} (${f['tarih']})',
                            overflow: TextOverflow.ellipsis),
                        onTap: () =>
                            seciliFaaliyetTarihi = f['tarih'].toString(),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setModalState(() => seciliFaaliyetBaslik = val),
                    dropdownColor: AppColors.inputFill,
                    style: const TextStyle(color: Colors.white),
                    decoration: _koyuInputDekorasyonu(
                        label: 'Bağlı Olduğu Faaliyet / Kamp',
                        icon: Icons.event),
                  )
                else if (isUpdate)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                        'Bağlı Faaliyet: ${seciliFaaliyetBaslik ?? '-'}',
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold)),
                  ),
                if (!isUpdate) const SizedBox(height: 16),
                TextField(
                  controller: baslikController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _koyuInputDekorasyonu(
                      label: 'Görev / İş Adı', icon: Icons.description),
                ),
                const SizedBox(height: 16),
                if (yoneticiler.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: seciliKisiId,
                    isExpanded: true,
                    items: yoneticiler.map((y) {
                      final adSoyad =
                          '${y['ad'] ?? ''} ${y['soyad'] ?? ''}'.trim();
                      final unvan = (y['unvan'] ?? '').toString().trim();
                      return DropdownMenuItem<String>(
                        value: y['id'].toString(),
                        child: Text(
                            unvan.isNotEmpty ? '$adSoyad ($unvan)' : adSoyad,
                            overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => seciliKisiId = val),
                    dropdownColor: AppColors.inputFill,
                    style: const TextStyle(color: Colors.white),
                    decoration: _koyuInputDekorasyonu(
                        label: 'Görev Atanan Yönetici',
                        icon: Icons.person_pin_circle),
                  ),
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
                      label: 'Durum', icon: Icons.stacked_bar_chart),
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

                    String sorumluEtiketi = 'Bilinmiyor';
                    if (seciliKisiId != null && yoneticiler.isNotEmpty) {
                      final sec = yoneticiler.firstWhere(
                          (y) => y['id'].toString() == seciliKisiId,
                          orElse: () => yoneticiler.first);
                      final u = (sec['unvan'] ?? '').toString().trim();
                      sorumluEtiketi = u.isNotEmpty
                          ? '${sec['ad']} ${sec['soyad']} ($u)'
                          : '${sec['ad']} ${sec['soyad']}';
                    }
                    String atayanEtiketi = 'Sistem';
                    if (aktifKullanici != null) {
                      final u =
                          (aktifKullanici['unvan'] ?? '').toString().trim();
                      atayanEtiketi = u.isNotEmpty
                          ? '${aktifKullanici['ad']} ${aktifKullanici['soyad']} ($u)'
                          : '${aktifKullanici['ad']} ${aktifKullanici['soyad']}';
                    }

                    final kayitVerisi = {
                      'baslik': baslikController.text.trim(),
                      'tarih': seciliFaaliyetTarihi ?? 'Tarihsiz',
                      'durum': durum,
                      'oncelik': 'Normal',
                      'hedef_birim': sorumluEtiketi,
                      'olusturan_unvan': atayanEtiketi,
                      'atanan_kisi_id': seciliKisiId,
                      'kategori': seciliFaaliyetBaslik ?? 'Genel Görev',
                    };

                    if (isUpdate) {
                      await supabase
                          .from('faaliyetler')
                          .update(kayitVerisi)
                          .eq('id', mevcutGorev['id']);
                    } else {
                      await supabase.from('faaliyetler').insert(kayitVerisi);
                    }

                    if (seciliKisiId != null && !isUpdate) {
                      await NotificationService.gorevBildirimiGonder(
                        hedefKullaniciId: seciliKisiId!,
                        faaliyetBaslik:
                            "${baslikController.text.trim()} ($seciliFaaliyetBaslik)",
                        tarih: seciliFaaliyetTarihi ?? '',
                        birim: 'Yeni Kanban Görevi',
                      );
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check, size: 20),
                  label: Text(isUpdate ? 'Güncelle' : 'Kaydet ve Ata',
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
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.white12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                        onTap: () => _kanbandanGorevEkleAc(mevcutGorev: isItem),
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
            const SizedBox(height: 6),
            if (isItem['kategori'] != null &&
                isItem['kategori'] != 'Genel' &&
                isItem['kategori'] != 'Genel Görev')
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('📂 ${isItem['kategori']}',
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            Text('📅 ${isItem['tarih'] ?? '-'}',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person, size: 12, color: AppColors.accent),
                const SizedBox(width: 4),
                Expanded(
                    child: Text('${isItem['hedef_birim'] ?? '-'}',
                        style: const TextStyle(
                            color: AppColors.accent, fontSize: 11))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // BURADA DEĞİŞİKLİK YAPILDI:
  // Dikeyde ekranı sıkıştıran `Expanded` yerine, sütunlara sabit genişlik (300 piksel) verip
  // `SingleChildScrollView(scrollDirection: Axis.horizontal)` sararak daralmayı ve harf dökülmesini çözdük.
  Widget _sutunOlustur(String baslik, String dbDurum,
      List<Map<String, dynamic>> isler, Color renk) {
    return Container(
      width: 290, // Sütunların telefonda ezilmemesi için sabit ideal genişlik
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: DragTarget<Map<String, dynamic>>(
        onAcceptWithDetails: (details) {
          final data = details.data;
          if (data['durum'] != dbDurum) {
            _durumGuncelle(data['id'].toString(), dbDurum);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            decoration: BoxDecoration(
              color: candidateData.isNotEmpty
                  ? renk.withValues(alpha: 0.1)
                  : AppColors.background.withValues(alpha: 0.5),
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
                    itemBuilder: (context, index) {
                      final isItem = isler[index];
                      return Draggable<Map<String, dynamic>>(
                        data: isItem,
                        feedback: Material(
                          color: Colors.transparent,
                          child:
                              SizedBox(width: 280, child: _kanbanKarti(isItem)),
                        ),
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
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        title: const Text('Kanban İş Takibi',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        onPressed: () => _kanbandanGorevEkleAc(),
        icon: const Icon(Icons.add_task, color: Colors.black),
        label: const Text('Alt Görev Ata',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('faaliyetler')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .map((maps) => List<Map<String, dynamic>>.from(maps)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }
          final tumGorevler =
              snapshot.hasData ? snapshot.data! : <Map<String, dynamic>>[];

          final yapilacak =
              tumGorevler.where((f) => f['durum'] == 'Yapılacak').toList();
          final yapiliyor =
              tumGorevler.where((f) => f['durum'] == 'Yapılıyor').toList();
          final tamamlandi =
              tumGorevler.where((f) => f['durum'] == 'Tamamlandı').toList();

          return Padding(
            padding: const EdgeInsets.all(8.0),
            // YATAY KAYDIRMA EKLENDİ: Sütunların ekrana sıkışıp harfleri alt alta dökmesini önler.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _sutunOlustur('Yapılacak', 'Yapılacak', yapilacak,
                      Colors.lightBlueAccent),
                  _sutunOlustur(
                      'Yapılıyor', 'Yapılıyor', yapiliyor, Colors.orangeAccent),
                  _sutunOlustur('Tamamlandı', 'Tamamlandı', tamamlandi,
                      Colors.greenAccent),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
