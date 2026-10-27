import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../core/faaliyet_servisi.dart';
import '../core/ortak.dart';
import '../widgets/faaliyet_form_dialog.dart';
import '../widgets/faaliyet_karti.dart';
import 'academy_calendar_screen.dart';
import 'faaliyet_detay_screen.dart';
import 'kanban_screen.dart';
import 'notes_screen.dart';
import 'pdf_screen.dart';
import 'profile_screen.dart';
import 'units_screen.dart';
import 'uye_yonetimi_screen.dart';
import 'pending_approvals_screen.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  String _filtre = 'Tümü';
  String _ilceFiltre = 'tum';
  Yetki? _yetki;
  bool _yukleniyor = true;
  late final Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = supabase
        .from('faaliyetler')
        .stream(primaryKey: ['id']).order('created_at', ascending: false);
    _yetkiYukle();
  }

  Future<void> _yetkiYukle() async {
    final y = await Yetki.yukle();
    if (!mounted) return;
    setState(() {
      _yetki = y;
      _yukleniyor = false;
    });
  }

  bool _ilceUygun(Map<String, dynamic> f) {
    if (_ilceFiltre == 'tum') return true;
    final i = f['ilce_id']?.toString();
    return _ilceFiltre == 'il' ? i == null : i == _ilceFiltre;
  }

  void _whatsappOzetKopyala(List<Map<String, dynamic>> faaliyetler) {
    String metin = '📌 *KOCAELİ GENÇ İHH YILLIK PLAN*\n\n';
    for (final f in faaliyetler) {
      metin += '🔹 *${f['baslik']}*\n'
          '📅 ${tarihGoster(f['tarih']?.toString())}\n'
          '🗺️ ${Ilceler.ad(f['ilce_id'])}\n'
          '📌 Durum: ${f['durum']}\n'
          '🏢 Sorumlu Birim: ${f['olusturan_unvan']}\n'
          '🎯 Hedef: ${f['hedef_birim']}\n'
          '✍️ Atayan: ${f['atayan_ad']}\n\n';
    }
    Clipboard.setData(ClipboardData(text: metin));
    bildir(context, 'WhatsApp özeti panoya kopyalandı!');
  }

  void _git(Widget ekran) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ekran));

  Widget _onayBandi() {
    final reddedildi = _yetki?.onay == 'reddedildi';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: (reddedildi ? Colors.redAccent : Colors.orangeAccent)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: (reddedildi ? Colors.redAccent : Colors.orangeAccent)
                  .withValues(alpha: 0.5))),
      child: Row(
        children: [
          Icon(reddedildi ? Icons.block : Icons.hourglass_top,
              color: reddedildi ? Colors.redAccent : Colors.orangeAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                reddedildi
                    ? 'Başvurunuz reddedildi. Lütfen yöneticinizle iletişime geçin.'
                    : 'Hesabınız onay bekliyor. Yöneticiniz birim ve yetkinizi atadığında tüm özellikler açılacak.',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _ilceDropdown() {
    final secenekler = <MapEntry<String, String>>[
      const MapEntry('tum', 'Tüm Teşkilat'),
      const MapEntry('il', 'İl (Merkez)'),
      ...Ilceler.liste
          .map((i) => MapEntry(i['id'].toString(), i['ad'].toString())),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: _ilceFiltre,
        isExpanded: true,
        dropdownColor: AppColors.inputFill,
        style: const TextStyle(color: Colors.white),
        decoration: koyuInput(
            label: 'İlçe / Teşkilat Filtresi', icon: Icons.location_city),
        items: secenekler.map((e) {
          return DropdownMenuItem<String>(
            value: e.key,
            child: Text(e.value),
          );
        }).toList(),
        onChanged: (v) {
          if (v != null) setState(() => _ilceFiltre = v);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
          backgroundColor: AppColors.secondary,
          body: Center(
              child: CircularProgressIndicator(color: AppColors.accent)));
    }
    final yetki = _yetki;
    final yazabilir = yetki?.yazabilir ?? false;
    final yonetim = (yetki?.admin ?? false) || (yetki?.ilceAdmini ?? false);

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
                      blurRadius: 8)
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
            onPressed: () => _git(const ProfileScreen()),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Veri çekilemedi.\nHata: ${snapshot.error}',
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 14))));
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }

          final faaliyetler = (snapshot.data ?? <Map<String, dynamic>>[])
              .where((f) => _ilceUygun(f) && f['onay_durumu'] != 'Bekliyor')
              .toList();
          int say(String d) => faaliyetler.where((f) => f['durum'] == d).length;

          var liste = faaliyetler;
          if (_filtre != 'Tümü') {
            liste = liste.where((f) => f['durum'] == _filtre).toList();
          }
          liste = tarihSirali(liste);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (yetki != null && yetki.bekliyor) _onayBandi(),
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
                          _istatistikKolon('Planlanan', '${say('Yapılacak')}',
                              Colors.lightBlueAccent),
                          Container(
                              height: 30, width: 1, color: Colors.white24),
                          _istatistikKolon('Yapılıyor', '${say('Yapılıyor')}',
                              Colors.orangeAccent),
                          Container(
                              height: 30, width: 1, color: Colors.white24),
                          _istatistikKolon('Tamamlandı', '${say('Tamamlandı')}',
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
                if (yonetim) ...[
                  _modulSatiri(
                      'Onay Bekleyenler',
                      'Eklenen yeni faaliyetleri onaylayın veya reddedin',
                      Icons.verified_user,
                      Colors.amberAccent,
                      () => _git(const PendingApprovalsScreen())),
                  const SizedBox(height: 10),
                  _modulSatiri(
                      'Üye Onayları & Yönetim',
                      'Yeni üyeleri onaylayın, birim ve yetki atayın',
                      Icons.how_to_reg,
                      Colors.amberAccent,
                      () => _git(const UyeYonetimiScreen())),
                  const SizedBox(height: 10),
                ],
                if (yazabilir) ...[
                  _modulSatiri(
                      'Yeni Faaliyet Ekle',
                      'Planlanan yeni bir etkinlik tanımlayın ve görev atayın',
                      Icons.add_box,
                      Colors.tealAccent,
                      () => faaliyetFormuAc(context)),
                  const SizedBox(height: 10),
                ],
                _modulSatiri(
                    'Alt Görevler & İş Takibi (Kanban)',
                    'Faaliyetleri sütunlar halinde yönetin',
                    Icons.view_kanban,
                    Colors.orangeAccent,
                    () => _git(const KanbanScreen())),
                const SizedBox(height: 10),
                _modulSatiri(
                    'Planlama Takvimi',
                    'Tüm planları ay ay görün ve ekleyin',
                    Icons.calendar_month,
                    Colors.purpleAccent,
                    () => _git(const AcademyCalendarScreen())),
                const SizedBox(height: 10),
                _modulSatiri(
                    'Birimlere Göre Faaliyetler',
                    'Birim ve komisyonların faaliyetlerini izleyin',
                    Icons.group,
                    Colors.lightBlueAccent,
                    () => _git(const UnitsScreen())),
                const SizedBox(height: 10),
                if (yazabilir) ...[
                  _modulSatiri(
                      'Toplantı Notları & Kararlar',
                      'Haftalık kararları tutun ve PDF çıktısı alın',
                      Icons.edit_document,
                      Colors.deepPurpleAccent,
                      () => _git(const NotesScreen())),
                  const SizedBox(height: 10),
                ],
                _modulSatiri(
                    'PDF Raporlar & Analiz',
                    'Faaliyetleri ve bütçeyi kurumsal PDF olarak indirin',
                    Icons.picture_as_pdf,
                    Colors.redAccent,
                    () => _git(const PdfScreen())),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Aktif Faaliyetler ve Planlar',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text('(${liste.length})',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 12),
                if (yetki?.admin ?? false) _ilceDropdown(),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Tümü', ...durumlar].map((filtre) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filtre),
                          selected: _filtre == filtre,
                          selectedColor: AppColors.background,
                          backgroundColor: AppColors.card,
                          labelStyle: TextStyle(
                              color: _filtre == filtre
                                  ? AppColors.accent
                                  : Colors.white70),
                          onSelected: (_) => setState(() => _filtre = filtre),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                if (liste.isEmpty)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Gösterilecek faaliyet bulunamadı.',
                              style: TextStyle(color: Colors.white54))))
                else
                  ...liste.map((f) => FaaliyetKarti(
                        f: f,
                        yetki: yetki,
                        onTap: () => _git(FaaliyetDetayScreen(
                            faaliyetId: f['id'].toString())),
                        onDuzenle: () => faaliyetFormuAc(context, mevcut: f),
                        onSil: () => FaaliyetServisi.sil(context, f),
                        onPaylas: () => _whatsappOzetKopyala([f]),
                      )),
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

  Widget _modulSatiri(String baslik, String altBaslik, IconData ikon,
      Color renk, VoidCallback onTap) {
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
