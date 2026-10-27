import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/ortak.dart';

class FaaliyetKarti extends StatelessWidget {
  final Map<String, dynamic> f;
  final Yetki? yetki;
  final VoidCallback? onTap, onDuzenle, onSil, onPaylas;

  const FaaliyetKarti({
    super.key,
    required this.f,
    this.yetki,
    this.onTap,
    this.onDuzenle,
    this.onSil,
    this.onPaylas,
  });

  Widget _satir(String metin,
      {Color renk = Colors.white70, double boyut = 13, bool kalin = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(metin,
          style: TextStyle(
              color: renk,
              fontSize: boyut,
              fontWeight: kalin ? FontWeight.bold : FontWeight.normal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renk = durumRengi(f['durum']?.toString());
    final yonet = yetki?.yonetebilir(f) ?? false;
    final kisi = (f['sorumlu_kisi_ad'] ?? '').toString();
    final konum = (f['konum_adi'] ?? '').toString();

    return Card(
      color: AppColors.card,
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: renk.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: renk.withValues(alpha: 0.5))),
                    child: Text(f['durum']?.toString() ?? 'Yapılacak',
                        style: TextStyle(
                            color: renk,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  if (onPaylas != null)
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.share,
                            size: 20, color: Colors.white70),
                        onPressed: onPaylas),
                  if (yonet && onDuzenle != null)
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit,
                            size: 20, color: Colors.blueAccent),
                        onPressed: onDuzenle),
                  if (yonet && onSil != null)
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete,
                            size: 20, color: Colors.redAccent),
                        onPressed: onSil),
                ],
              ),
              const SizedBox(height: 6),
              if (f['bagli_faaliyet_baslik'] != null)
                _satir('🔗 Ana Etkinlik: ${f['bagli_faaliyet_baslik']}',
                    renk: Colors.tealAccent, boyut: 11, kalin: true),
              Text(f['baslik']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 4),
              _satir('📅 ${tarihGoster(f['tarih']?.toString())}'),
              _satir(
                  '🏢 Sorumlu Birim: ${f['olusturan_unvan'] ?? 'Belirtilmedi'}'),
              if (kisi.isNotEmpty) _satir('👤 Sorumlu Kişi: $kisi'),
              _satir('🎯 Hedef Komisyon: ${f['hedef_birim'] ?? 'Genel'}'),
              if (konum.isNotEmpty) _satir('📍 $konum'),
              _satir('✍️ Atayan: ${f['atayan_ad'] ?? '-'}',
                  renk: AppColors.accent, kalin: true),
            ],
          ),
        ),
      ),
    );
  }
}
