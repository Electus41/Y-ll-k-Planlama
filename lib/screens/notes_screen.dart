import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String? _seciliFiltreTarihi;
  List<Map<String, dynamic>> _notlar = [];
  bool _yukleniyor = true;

  bool _isAdmin = false;
  String _kullaniciBirim = 'Bilinmeyen Birim';

  final List<String> aylar = const [
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
    _yetkiVeNotlariGetir();
  }

  Future<void> _yetkiVeNotlariGetir() async {
    setState(() => _yukleniyor = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profil = await Supabase.instance.client
            .from('profiller')
            .select('unvan, yetki_seviyesi')
            .eq('id', user.id)
            .maybeSingle();

        if (profil != null) {
          _kullaniciBirim = profil['unvan'] ?? 'Bilinmeyen Birim';
          _isAdmin = (profil['yetki_seviyesi'] == 'Admin' ||
              profil['unvan'] == 'İl Başkanı' ||
              profil['unvan'] == 'Teşkilatlanma Başkanı' ||
              profil['unvan'] == 'Gölge Başkan');
        }
      }
      await _notlariCek();
    } catch (e) {
      debugPrint('Yetki/not getirme hatası: $e');
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _notlariCek() async {
    try {
      var query = Supabase.instance.client.from('toplanti_notlari').select();

      if (!_isAdmin) {
        query = query.eq('olusturan_birim', _kullaniciBirim);
      }

      if (_seciliFiltreTarihi != null) {
        query = query.eq('tarih', _seciliFiltreTarihi!);
      }

      final data = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _notlar = List<Map<String, dynamic>>.from(data);
          _yukleniyor = false;
        });
      }
    } catch (e) {
      debugPrint('Notlar çekilemedi: $e');
      if (mounted) {
        setState(() => _yukleniyor = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Notlar yüklenemedi.'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _notSil(Map<String, dynamic> not) async {
    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF161C1A),
            title:
                const Text('Notu Sil', style: TextStyle(color: Colors.white)),
            content: const Text(
                'Bu notu kalıcı olarak silmek istediğinize emin misiniz?',
                style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('İptal',
                      style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  onPressed: () => Navigator.pop(ctx, true),
                  child:
                      const Text('Sil', style: TextStyle(color: Colors.white))),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await Supabase.instance.client
          .from('toplanti_notlari')
          .delete()
          .eq('id', not['id']);
      await _notlariCek();
    } catch (e) {
      debugPrint('Not silinemedi: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Not silinemedi. Yetkiniz olmayabilir.'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _pdfYazdirVeyaPaylas(Map<String, dynamic> not) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final olusturanBirim = not['olusturan_birim'] ?? 'Bilinmeyen Birim';
    final yesil = PdfColor.fromInt(0xFF1B4D3E);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('KOCAELİ GENÇ İHH',
                        style: pw.TextStyle(
                            color: yesil,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Kurumsal Toplantı Karar Tutanağı',
                        style: pw.TextStyle(
                            color: PdfColors.grey700, fontSize: 12)),
                  ],
                ),
                pw.Text('Tarih: ${not['tarih']}',
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(color: yesil, thickness: 2),
            pw.SizedBox(height: 12),
            pw.Text('Toplantıyı Yapan Birim: $olusturanBirim',
                style: pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey800,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Gündem / Konu: ',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Expanded(
                      child: pw.Text(not['konu'] ?? '',
                          style: pw.TextStyle(fontSize: 12))),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text('ALINAN KARARLAR VE NOTLAR:',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: yesil)),
            pw.SizedBox(height: 12),
            pw.Text(not['notlar'] ?? '',
                style: pw.TextStyle(fontSize: 11, lineSpacing: 1.6)),
            pw.SizedBox(height: 60),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text('Toplantı Başkanı',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.SizedBox(height: 40),
                    pw.Container(width: 120, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('İmza',
                        style: pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('Yazman / Sorumlu',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.SizedBox(height: 40),
                    pw.Container(width: 120, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('İmza',
                        style: pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ],
            )
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Toplanti_Notu_${not['tarih'].toString().replaceAll(' ', '_')}.pdf',
    );
  }

  Widget _tarihDropdown(
      {required String value,
      required List<String> items,
      required void Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
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

  Future<void> _filtreDialogAc() async {
    DateTime sTarih = DateTime.now();
    String seciliGun = sTarih.day.toString();
    String seciliAy = aylar[sTarih.month - 1];
    String seciliYil = sTarih.year.toString();

    if (_seciliFiltreTarihi != null) {
      try {
        var parcalar = _seciliFiltreTarihi!.split(' ');
        if (parcalar.length == 3) {
          seciliGun = parcalar[0];
          seciliAy = parcalar[1];
          seciliYil = parcalar[2];
        }
      } catch (_) {}
    }

    if (!['2026', '2027', '2028', '2029', '2030'].contains(seciliYil)) {
      seciliYil = '2026';
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF161C1A),
            title: const Text('Tarihe Göre Filtrele',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Toplantı Tarihi:',
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
                            items: const [
                              '2026',
                              '2027',
                              '2028',
                              '2029',
                              '2030'
                            ],
                            onChanged: (val) =>
                                setModalState(() => seciliYil = val!))),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İptal',
                      style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black),
                onPressed: () {
                  _seciliFiltreTarihi = '$seciliGun $seciliAy $seciliYil';
                  Navigator.pop(ctx);
                  _notlariCek();
                },
                child: const Text('Uygula',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Toplantı Notları & Kararlar',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_seciliFiltreTarihi != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off, color: Colors.redAccent),
              tooltip: 'Filtreyi Temizle',
              onPressed: () {
                setState(() => _seciliFiltreTarihi = null);
                _notlariCek();
              },
            ),
          IconButton(
            icon: Icon(Icons.filter_alt,
                color: _seciliFiltreTarihi != null
                    ? AppColors.accent
                    : Colors.white),
            tooltip: 'Tarihe Göre Filtrele',
            onPressed: _filtreDialogAc,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        onPressed: () async {
          final sonuc = await Navigator.push(
              context,
              MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (context) =>
                      NotEkleDuzenleEkrani(olusturanBirim: _kullaniciBirim)));
          if (sonuc == true) {
            _notlariCek();
          }
        },
        icon: const Icon(Icons.edit_document),
        label: const Text('Yeni Not',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          if (_seciliFiltreTarihi != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: AppColors.accent.withValues(alpha: 0.1),
              child: Text('Filtre Uygulandı: $_seciliFiltreTarihi',
                  style: const TextStyle(
                      color: AppColors.accent, fontWeight: FontWeight.bold)),
            ),
          Expanded(
            child: _yukleniyor
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : _notlar.isEmpty
                    ? const Center(
                        child: Text('Görüntülenecek toplantı notu yok.',
                            style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notlar.length,
                        itemBuilder: (context, index) {
                          final not = _notlar[index];
                          return Card(
                            color: AppColors.card,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Colors.white12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                            color: AppColors.accent
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Text('📅 ${not['tarih']}',
                                            style: const TextStyle(
                                                color: AppColors.accent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                              icon: const Icon(
                                                  Icons.picture_as_pdf,
                                                  color: Colors.redAccent,
                                                  size: 22),
                                              tooltip: 'Kurumsal PDF Çıktısı',
                                              onPressed: () =>
                                                  _pdfYazdirVeyaPaylas(not)),
                                          IconButton(
                                              icon: const Icon(Icons.edit,
                                                  color: Colors.blueAccent,
                                                  size: 22),
                                              onPressed: () async {
                                                final sonuc = await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        fullscreenDialog: true,
                                                        builder: (context) =>
                                                            NotEkleDuzenleEkrani(
                                                                mevcutNot: not,
                                                                olusturanBirim:
                                                                    _kullaniciBirim)));
                                                if (sonuc == true) {
                                                  _notlariCek();
                                                }
                                              }),
                                          IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.white38,
                                                  size: 22),
                                              onPressed: () => _notSil(not)),
                                        ],
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(not['konu'] ?? 'Konu Belirtilmedi',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                      '🏢 Toplantıyı Yapan: ${not['olusturan_birim'] ?? '-'}',
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text(not['notlar'] ?? '',
                                      maxLines: 4,
                                      overflow: TextOverflow.fade,
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          height: 1.4)),
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

class NotEkleDuzenleEkrani extends StatefulWidget {
  final Map<String, dynamic>? mevcutNot;
  final String olusturanBirim;

  const NotEkleDuzenleEkrani(
      {super.key, this.mevcutNot, required this.olusturanBirim});

  @override
  State<NotEkleDuzenleEkrani> createState() => _NotEkleDuzenleEkraniState();
}

class _NotEkleDuzenleEkraniState extends State<NotEkleDuzenleEkrani> {
  late TextEditingController _konuController;
  late TextEditingController _notlarController;

  final FocusNode _notlarFocus = FocusNode();

  final List<String> aylar = const [
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

  late String seciliGun;
  late String seciliAy;
  late String seciliYil;
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    _konuController =
        TextEditingController(text: widget.mevcutNot?['konu'] ?? '');
    _notlarController =
        TextEditingController(text: widget.mevcutNot?['notlar'] ?? '');

    DateTime sTarih = DateTime.now();
    seciliGun = sTarih.day.toString();
    seciliAy = aylar[sTarih.month - 1];
    seciliYil = sTarih.year.toString();

    if (widget.mevcutNot != null && widget.mevcutNot!['tarih'] != null) {
      try {
        var parcalar = widget.mevcutNot!['tarih'].toString().split(' ');
        if (parcalar.length == 3) {
          seciliGun = parcalar[0];
          seciliAy = parcalar[1];
          seciliYil = parcalar[2];
        }
      } catch (_) {}
    }

    if (!['2026', '2027', '2028', '2029', '2030'].contains(seciliYil)) {
      seciliYil = '2026';
    }
  }

  @override
  void dispose() {
    _konuController.dispose();
    _notlarController.dispose();
    _notlarFocus.dispose();
    super.dispose();
  }

  Widget _tarihDropdown(
      {required String value,
      required List<String> items,
      required void Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
      items:
          items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      dropdownColor: AppColors.secondary,
      icon: const Icon(Icons.keyboard_arrow_down,
          color: Colors.white54, size: 16),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.secondary.withValues(alpha: 0.5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  void _metinEkle(String eklenecek) {
    final metin = _notlarController.text;
    final baslangic = _notlarController.selection.start;
    final bitis = _notlarController.selection.end;

    if (baslangic >= 0 && bitis >= 0) {
      final yeniMetin = metin.replaceRange(baslangic, bitis, eklenecek);
      _notlarController.value = TextEditingValue(
        text: yeniMetin,
        selection:
            TextSelection.collapsed(offset: baslangic + eklenecek.length),
      );
    } else {
      _notlarController.text += eklenecek;
    }
    _notlarFocus.requestFocus();
  }

  Future<void> _kaydet() async {
    if (_konuController.text.trim().isEmpty ||
        _notlarController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lütfen konu ve not içeriğini boş bırakmayın.'),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => _kaydediliyor = true);

    try {
      final tarihStr = '$seciliGun $seciliAy $seciliYil';
      final data = {
        'tarih': tarihStr,
        'konu': _konuController.text.trim(),
        'notlar': _notlarController.text.trim(),
        'olusturan_birim': widget.mevcutNot != null
            ? widget.mevcutNot!['olusturan_birim']
            : widget.olusturanBirim
      };

      if (widget.mevcutNot != null) {
        await Supabase.instance.client
            .from('toplanti_notlari')
            .update(data)
            .eq('id', widget.mevcutNot!['id']);
      } else {
        await Supabase.instance.client.from('toplanti_notlari').insert(data);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Not kaydedilemedi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Not kaydedilemedi. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _kaydediliyor = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => Navigator.pop(context, false),
          tooltip: 'İptal',
        ),
        title: Text(widget.mevcutNot != null ? 'Notu Düzenle' : 'Yeni Not',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20))),
              onPressed: _kaydediliyor ? null : _kaydet,
              icon: _kaydediliyor
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.check, size: 18),
              label: const Text('Kaydet',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            color: AppColors.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month,
                        color: Colors.white54, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                        flex: 2,
                        child: _tarihDropdown(
                            value: seciliGun,
                            items: List.generate(31, (i) => (i + 1).toString()),
                            onChanged: (val) =>
                                setState(() => seciliGun = val!))),
                    const SizedBox(width: 8),
                    Expanded(
                        flex: 3,
                        child: _tarihDropdown(
                            value: seciliAy,
                            items: aylar,
                            onChanged: (val) =>
                                setState(() => seciliAy = val!))),
                    const SizedBox(width: 8),
                    Expanded(
                        flex: 2,
                        child: _tarihDropdown(
                            value: seciliYil,
                            items: const [
                              '2026',
                              '2027',
                              '2028',
                              '2029',
                              '2030'
                            ],
                            onChanged: (val) =>
                                setState(() => seciliYil = val!))),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _konuController,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: 'Toplantı Konusu...',
                    hintStyle: TextStyle(
                        color: Colors.white30,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: AppColors.secondary,
            child: Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.format_list_bulleted,
                        color: Colors.white),
                    tooltip: 'Madde İşareti',
                    onPressed: () => _metinEkle('\n• ')),
                IconButton(
                    icon: const Icon(Icons.format_list_numbered,
                        color: Colors.white),
                    tooltip: 'Sayısal Maddeleme',
                    onPressed: () => _metinEkle('\n1. ')),
                IconButton(
                    icon:
                        const Icon(Icons.horizontal_rule, color: Colors.white),
                    tooltip: 'Tire İşareti',
                    onPressed: () => _metinEkle('\n- ')),
                IconButton(
                    icon: const Icon(Icons.check_box_outline_blank,
                        color: Colors.white),
                    tooltip: 'Görev Kutucuğu',
                    onPressed: () => _metinEkle('\n[ ] ')),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: AppColors.card.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _notlarController,
                focusNode: _notlarFocus,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, height: 1.6),
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText:
                      'Alınan kararları, görevleri ve notlarınızı buraya yazmaya başlayın...',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 16),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
