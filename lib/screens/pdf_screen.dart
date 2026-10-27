import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants.dart';
import '../core/ortak.dart';

class PdfScreen extends StatefulWidget {
  const PdfScreen({super.key});

  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  bool _hazirlaniyor = false;
  Yetki? _yetki;

  @override
  void initState() {
    super.initState();
    Yetki.yukle().then((y) {
      if (mounted) setState(() => _yetki = y);
    });
  }

  Future<void> _calistir(Future<void> Function() is_) async {
    setState(() => _hazirlaniyor = true);
    try {
      await is_();
    } catch (e) {
      debugPrint('PDF hatası: $e');
      if (mounted) {
        bildir(
            context, 'PDF oluşturulamadı. İnternet bağlantınızı kontrol edin.',
            renk: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _hazirlaniyor = false);
    }
  }

  Future<void> _faaliyetRaporu(String durumFiltresi) => _calistir(() async {
        final veri = await supabase.from('faaliyetler').select();
        var liste = List<Map<String, dynamic>>.from(veri);
        if (durumFiltresi != 'Tümü') {
          liste = liste.where((f) => f['durum'] == durumFiltresi).toList();
        }
        liste = tarihSirali(liste);

        final font = await PdfGoogleFonts.robotoRegular();
        final boldFont = await PdfGoogleFonts.robotoBold();
        final yesil = PdfColor.fromInt(0xFF1B4D3E);
        final pdf = pw.Document();

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            theme: pw.ThemeData.withFont(base: font, bold: boldFont),
            build: (context) => [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('KOCAELİ GENÇ İHH - FAALİYET RAPORU',
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Filtre: $durumFiltresi (${liste.length})',
                        style: pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Faaliyet',
                  'Sorumlu Birim',
                  'Sorumlu Kişi',
                  'Hedef Komisyon',
                  'Tarih',
                  'Konum',
                  'Atayan',
                  'Durum'
                ],
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 9),
                headerDecoration: pw.BoxDecoration(color: yesil),
                cellStyle: pw.TextStyle(fontSize: 8),
                data: liste
                    .map((f) => [
                          f['baslik']?.toString() ?? '-',
                          f['olusturan_unvan']?.toString() ?? '-',
                          (f['sorumlu_kisi_ad'] ?? '').toString().isEmpty
                              ? '-'
                              : f['sorumlu_kisi_ad'].toString(),
                          f['hedef_birim']?.toString() ?? '-',
                          tarihGoster(f['tarih']?.toString()),
                          (f['konum_adi'] ?? '').toString().isEmpty
                              ? '-'
                              : f['konum_adi'].toString(),
                          f['atayan_ad']?.toString() ?? '-',
                          f['durum']?.toString() ?? '-',
                        ])
                    .toList(),
              ),
            ],
          ),
        );

        final Uint8List bytes = await pdf.save();
        await Printing.sharePdf(
            bytes: bytes,
            filename: 'Kocaeli_Genc_IHH_Rapor_$durumFiltresi.pdf');
      });

  Future<void> _butceRaporu() => _calistir(() async {
        final veri = await supabase.from('faaliyet_butce_kalemleri').select(
            'faaliyet_id, kalem, tahmini_tutar, gerceklesen_tutar, alindi, faaliyetler(baslik, olusturan_unvan, tarih)');
        final kalemler = List<Map<String, dynamic>>.from(veri);
        if (kalemler.isEmpty) {
          if (mounted) {
            bildir(context, 'Raporlanacak bütçe kalemi bulunamadı.',
                renk: Colors.orange);
          }
          return;
        }

        final birimToplam =
            <String, List<double>>{}; // [tahmini, gerçek, kalem]
        final faalToplam = <String, Map<String, dynamic>>{};
        for (final k in kalemler) {
          final fa = k['faaliyetler'] as Map? ?? {};
          final birim = (fa['olusturan_unvan'] ?? 'Belirtilmemiş').toString();
          final t = sayi(k['tahmini_tutar']);
          final g = sayi(k['gerceklesen_tutar']);
          final b = birimToplam.putIfAbsent(birim, () => [0, 0, 0]);
          b[0] += t;
          b[1] += g;
          b[2] += 1;
          final fid = k['faaliyet_id'].toString();
          final f = faalToplam.putIfAbsent(
              fid,
              () => {
                    'baslik': fa['baslik'] ?? '-',
                    'birim': birim,
                    'tarih': tarihGoster(fa['tarih']?.toString()),
                    't': 0.0,
                    'g': 0.0,
                    'n': 0,
                  });
          f['t'] = (f['t'] as double) + t;
          f['g'] = (f['g'] as double) + g;
          f['n'] = (f['n'] as int) + 1;
        }

        final font = await PdfGoogleFonts.robotoRegular();
        final boldFont = await PdfGoogleFonts.robotoBold();
        final yesil = PdfColor.fromInt(0xFF1B4D3E);
        final basStil = pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 9);
        final pdf = pw.Document();

        final birimler = birimToplam.keys.toList()..sort();
        final topT = birimToplam.values.fold<double>(0, (s, v) => s + v[0]);
        final topG = birimToplam.values.fold<double>(0, (s, v) => s + v[1]);

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            theme: pw.ThemeData.withFont(base: font, bold: boldFont),
            build: (context) => [
              pw.Text('KOCAELİ GENÇ İHH - BÜTÇE RAPORU',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text('Birim Bazlı Özet',
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: yesil)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Birim', 'Kalem', 'Tahmini', 'Gerçekleşen', 'Kalan'],
                headerStyle: basStil,
                headerDecoration: pw.BoxDecoration(color: yesil),
                cellStyle: pw.TextStyle(fontSize: 9),
                data: [
                  ...birimler.map((b) {
                    final v = birimToplam[b]!;
                    return [
                      b,
                      v[2].toInt().toString(),
                      para(v[0]),
                      para(v[1]),
                      para(v[0] - v[1]),
                    ];
                  }),
                  ['TOPLAM', '', para(topT), para(topG), para(topT - topG)],
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('Faaliyet Bazlı Dağılım',
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: yesil)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Faaliyet',
                  'Birim',
                  'Tarih',
                  'Tahmini',
                  'Gerçekleşen'
                ],
                headerStyle: basStil,
                headerDecoration: pw.BoxDecoration(color: yesil),
                cellStyle: pw.TextStyle(fontSize: 8),
                data: faalToplam.values
                    .map((f) => [
                          f['baslik'].toString(),
                          f['birim'].toString(),
                          f['tarih'].toString(),
                          para(f['t'] as double),
                          para(f['g'] as double),
                        ])
                    .toList(),
              ),
            ],
          ),
        );

        final Uint8List bytes = await pdf.save();
        await Printing.sharePdf(
            bytes: bytes, filename: 'Kocaeli_Genc_IHH_Butce_Raporu.pdf');
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PDF Raporlar & Analiz',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _hazirlaniyor
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent))
            : ListView(
                children: [
                  const Text('Kurumsal Faaliyet Çıktısı Alın',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                      'İstediğiniz kapsamı seçerek plan ve görevleri PDF olarak indirebilir veya paylaşabilirsiniz.',
                      style: TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 24),
                  _raporButonu('Tüm Yıllık Faaliyet Raporu (Tümü)',
                      Colors.tealAccent, () => _faaliyetRaporu('Tümü')),
                  const SizedBox(height: 12),
                  _raporButonu(
                      'Planlanan Faaliyetler (Yapılacak)',
                      Colors.lightBlueAccent,
                      () => _faaliyetRaporu('Yapılacak')),
                  const SizedBox(height: 12),
                  _raporButonu('Devam Eden Faaliyetler (Yapılıyor)',
                      Colors.orangeAccent, () => _faaliyetRaporu('Yapılıyor')),
                  const SizedBox(height: 12),
                  _raporButonu('Tamamlanan Faaliyetler Raporu',
                      Colors.greenAccent, () => _faaliyetRaporu('Tamamlandı')),
                  if (_yetki?.yazabilir ?? false) ...[
                    const SizedBox(height: 24),
                    const Text('Bütçe',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _raporButonu('Birim Bazlı Harcama & Bütçe Raporu',
                        Colors.amberAccent, _butceRaporu),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _raporButonu(String baslik, Color renk, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.card,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: renk.withValues(alpha: 0.4))),
      ),
      onPressed: onTap,
      icon: Icon(Icons.picture_as_pdf, color: renk),
      label: Text(baslik,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }
}
