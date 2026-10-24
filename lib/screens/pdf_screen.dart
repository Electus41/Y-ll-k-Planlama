import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';

class PdfScreen extends StatefulWidget {
  const PdfScreen({super.key});

  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  bool _isGenerating = false;

  Future<void> _pdfOlusturVeYazdir(BuildContext context) async {
    setState(() => _isGenerating = true);

    try {
      final data = await supabase
          .from('faaliyetler')
          .select()
          .order('created_at', ascending: false);
      final faaliyetler = List<Map<String, dynamic>>.from(data);

      final planlanan =
          faaliyetler.where((f) => f['durum'] == 'Yapılacak').length;
      final yapiliyor =
          faaliyetler.where((f) => f['durum'] == 'Yapılıyor').length;
      final tamamlanan =
          faaliyetler.where((f) => f['durum'] == 'Tamamlandı').length;

      final pdf = pw.Document();

      // Türkçe karakter desteği için Roboto fontları
      final fontRegular = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();
      final fontMedium = await PdfGoogleFonts.robotoMedium();

      const anaRenk = PdfColor.fromInt(0xFF1B4D3E); // Genç İHH Yeşili
      const acikGri = PdfColor.fromInt(0xFFF9FAFB);
      const koyuGri = PdfColor.fromInt(0xFF374151);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          // ÜST BİLGİ (HEADER)
          header: (context) => pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('KOCAELİ GENÇ İHH',
                          style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 24,
                              color: anaRenk,
                              letterSpacing: 1.2)),
                      pw.SizedBox(height: 4),
                      pw.Text('Faaliyet ve Operasyon Raporu',
                          style: pw.TextStyle(
                              font: fontMedium, fontSize: 12, color: koyuGri)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Rapor Tarihi',
                          style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 10,
                              color: PdfColors.grey600)),
                      pw.Text(
                          DateFormat('dd.MM.yyyy - HH:mm')
                              .format(DateTime.now()),
                          style: pw.TextStyle(
                              font: fontBold, fontSize: 12, color: anaRenk)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: anaRenk, thickness: 2),
              pw.SizedBox(height: 24),
            ],
          ),
          // ALT BİLGİ (FOOTER)
          footer: (context) => pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300, thickness: 1),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                      'Bu rapor Kocaeli Genç İHH Yönetim Sistemi tarafından otomatik oluşturulmuştur.',
                      style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 8,
                          color: PdfColors.grey600)),
                  pw.Text('Sayfa ${context.pageNumber} / ${context.pagesCount}',
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 9, color: anaRenk)),
                ],
              ),
            ],
          ),
          // İÇERİK (BODY)
          build: (context) => [
            // İSTATİSTİK KARTLARI
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _istatistikKarti('Planlanan', planlanan.toString(),
                    PdfColors.blue700, fontBold, fontMedium),
                _istatistikKarti('Yapılıyor', yapiliyor.toString(),
                    PdfColors.orange700, fontBold, fontMedium),
                _istatistikKarti('Tamamlandı', tamamlanan.toString(),
                    PdfColors.green700, fontBold, fontMedium),
                _istatistikKarti('Toplam', faaliyetler.length.toString(),
                    anaRenk, fontBold, fontMedium),
              ],
            ),
            pw.SizedBox(height: 30),

            // LİSTE BAŞLIĞI
            pw.Text('DETAYLI FAALİYET DÖKÜMÜ',
                style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 14,
                    color: koyuGri,
                    letterSpacing: 1.1)),
            pw.SizedBox(height: 12),

            // ŞIK VE MODERN TABLO
            pw.TableHelper.fromTextArray(
              context: context,
              headers: [
                'Durum',
                'Faaliyet Adı',
                'Tarih',
                'Sorumlu Birim',
                'Yetkili'
              ],
              data: faaliyetler
                  .map((f) => [
                        f['durum'] ?? '-',
                        f['baslik'] ?? '-',
                        f['tarih'] ?? '-',
                        f['hedef_birim'] ?? '-',
                        f['olusturan_unvan'] ?? '-',
                      ])
                  .toList(),
              border: null,
              headerStyle: pw.TextStyle(
                  font: fontBold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(
                color: anaRenk,
                borderRadius:
                    pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey200, width: 1)),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle:
                  pw.TextStyle(font: fontRegular, color: koyuGri, fontSize: 9),
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              oddRowDecoration: const pw.BoxDecoration(color: acikGri),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            'Genc_IHH_Faaliyet_Raporu_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('PDF oluşturulurken hata: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // PDF içi kart yapıcı
  pw.Widget _istatistikKarti(String baslik, String deger, PdfColor renk,
      pw.Font fontBold, pw.Font fontMedium) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: renk.withAlpha(0.3), width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(deger,
              style: pw.TextStyle(font: fontBold, fontSize: 20, color: renk)),
          pw.SizedBox(height: 4),
          pw.Text(baslik,
              style: pw.TextStyle(
                  font: fontMedium, fontSize: 10, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121816),
      appBar: AppBar(
        title: const Text('Raporlama Merkezi',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF1B4D3E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2220),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF69F0AE).withValues(alpha: 0.1),
                        blurRadius: 40,
                        spreadRadius: 10),
                  ],
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    size: 80, color: Color(0xFF69F0AE)),
              ),
              const SizedBox(height: 32),
              const Text(
                'Kurumsal Faaliyet Raporu',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tüm sistemdeki güncel faaliyetler, görev durumları ve teşkilat performans analizleri derlenerek kurumsal PDF formatında dışa aktarılacaktır.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF69F0AE),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                  ),
                  onPressed:
                      _isGenerating ? null : () => _pdfOlusturVeYazdir(context),
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2))
                      : const Icon(Icons.print, size: 24),
                  label: Text(
                    _isGenerating
                        ? 'Rapor Derleniyor...'
                        : 'Raporu Oluştur & Yazdır',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
