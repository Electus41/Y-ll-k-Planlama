import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants.dart';

class PdfScreen extends StatefulWidget {
  const PdfScreen({super.key});

  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  bool _hazirlaniyor = false;

  Future<void> _pdfOlusturVeIndir(String durumFiltresi) async {
    setState(() => _hazirlaniyor = true);
    try {
      final veri = await supabase
          .from('faaliyetler')
          .select()
          .order('created_at', ascending: false);
      List<Map<String, dynamic>> liste = List<Map<String, dynamic>>.from(veri);
      if (durumFiltresi != 'Tümü') {
        liste = liste.where((f) => f['durum'] == durumFiltresi).toList();
      }

      final font = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
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
                      style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: [
                'Faaliyet Başlığı',
                'Birim',
                'Sorumlu',
                'Tarih',
                'Durum'
              ],
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1B4D3E)),
              cellStyle: const pw.TextStyle(fontSize: 10),
              data: liste
                  .map((f) => [
                        f['baslik']?.toString() ?? '-',
                        f['hedef_birim']?.toString() ?? '-',
                        f['olusturan_unvan']?.toString() ?? '-',
                        f['tarih']?.toString() ?? '-',
                        f['durum']?.toString() ?? '-',
                      ])
                  .toList(),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name: 'Kocaeli_Genc_IHH_Rapor.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('PDF Hatası: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _hazirlaniyor = false);
    }
  }

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
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Kurumsal Faaliyet Çıktısı Alın',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'İstediğiniz kapsamı seçerek tüm plan ve görevleri Türkçe karakter uyumlu PDF tablosu olarak indirebilir veya paylaşabilirsiniz.',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  _raporButonu('Tüm Yıllık Faaliyet Raporu (Tümü)',
                      Icons.assessment, Colors.tealAccent, 'Tümü'),
                  const SizedBox(height: 12),
                  _raporButonu('Planlanan Faaliyetler (Yapılacak)',
                      Icons.schedule, Colors.lightBlueAccent, 'Yapılacak'),
                  const SizedBox(height: 12),
                  _raporButonu('Devam Eden Faaliyetler (Yapılıyor)',
                      Icons.timelapse, Colors.orangeAccent, 'Yapılıyor'),
                  const SizedBox(height: 12),
                  _raporButonu(
                      'Tamamlanan Faaliyetler Raporu',
                      Icons.check_circle_outline,
                      Colors.greenAccent,
                      'Tamamlandı'),
                ],
              ),
      ),
    );
  }

  Widget _raporButonu(String baslik, IconData ikon, Color renk, String filtre) {
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
      onPressed: () => _pdfOlusturVeIndir(filtre),
      icon: Icon(Icons.picture_as_pdf, color: renk),
      label: Text(baslik,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }
}
