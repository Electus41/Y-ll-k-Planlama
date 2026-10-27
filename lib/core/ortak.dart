import 'package:flutter/material.dart';
import 'constants.dart';

const List<String> aylar = [
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

const List<String> durumlar = ['Yapılacak', 'Yapılıyor', 'Tamamlandı'];
const List<String> oncelikler = ['Acil', 'Normal', 'Düşük'];
const List<String> ustUnvanlar = [
  'İl Başkanı',
  'Teşkilatlanma Başkanı',
  'Gölge Başkan'
];
const List<String> birimKategorileri = [
  'Yönetim',
  'İcra Birimi',
  'Hedef Kitle Komisyonu'
];
const String komisyonKategorisi = 'Hedef Kitle Komisyonu';
const Color kutuRengi = Color(0xFF161C1A);

Color durumRengi(String? d) {
  switch (d) {
    case 'Tamamlandı':
      return Colors.greenAccent;
    case 'Yapılıyor':
      return Colors.orangeAccent;
    default:
      return Colors.lightBlueAccent;
  }
}

InputDecoration koyuInput({required String label, required IconData icon}) {
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

void bildir(BuildContext context, String metin, {Color renk = Colors.green}) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(metin), backgroundColor: renk));
}

Future<bool> onayDialogu(BuildContext context,
    {required String baslik, String? mesaj, String onayMetni = 'Sil'}) async {
  final sonuc = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kutuRengi,
      title: Text(baslik, style: const TextStyle(color: Colors.white)),
      content: mesaj == null
          ? null
          : Text(mesaj, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('İptal', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text(onayMetni, style: const TextStyle(color: Colors.white))),
      ],
    ),
  );
  return sonuc ?? false;
}

// ---------- İsim yardımcıları ----------
String tamAdGetir(Map<String, dynamic>? p) =>
    p == null ? '' : '${p['ad'] ?? ''} ${p['soyad'] ?? ''}'.trim();

String kisiEtiketi(Map<String, dynamic> p) {
  final a = tamAdGetir(p);
  final ad = a.isEmpty ? 'İsimsiz' : a;
  final u = (p['unvan'] ?? '').toString().trim();
  return u.isEmpty ? ad : '$ad ($u)';
}

/// Kişi seçici: seçili kutuda tek satır, açılan listede isim + unvan alt alta.
Widget kisiDropdown({
  required List<Map<String, dynamic>> kisiler,
  required String? deger,
  required ValueChanged<String?> onChanged,
  required String etiketMetni,
  String bosMetin = 'Kişi seçilmedi',
}) {
  final gecerli =
      kisiler.any((k) => k['id'].toString() == deger) ? deger : null;
  return DropdownButtonFormField<String>(
    value: gecerli,
    isExpanded: true,
    itemHeight: 56,
    dropdownColor: AppColors.inputFill,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: koyuInput(label: etiketMetni, icon: Icons.person_pin_circle),
    selectedItemBuilder: (_) => <Widget>[
      Text(bosMetin, maxLines: 1, overflow: TextOverflow.ellipsis),
      ...kisiler.map((k) =>
          Text(kisiEtiketi(k), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
    items: [
      DropdownMenuItem<String>(value: null, child: Text(bosMetin)),
      ...kisiler.map((k) {
        final a = tamAdGetir(k);
        final u = (k['unvan'] ?? '').toString().trim();
        return DropdownMenuItem<String>(
          value: k['id'].toString(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.isEmpty ? 'İsimsiz' : a,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (u.isNotEmpty)
                Text(u,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
        );
      }),
    ],
    onChanged: onChanged,
  );
}

// ---------- Tarih yardımcıları ----------
final RegExp _ayRegex =
    RegExp(r'^(\d{1,2})\s*([A-Za-zÇĞİÖŞÜçğıöşü]+)\s*(\d{4})$');
final RegExp _noktaRegex = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$');

DateTime? _tekTarih(String s) {
  final t = s.trim();
  final m = _ayRegex.firstMatch(t);
  if (m != null) {
    final ayAdi = m.group(2)!.toLowerCase();
    final ay = aylar.indexWhere((a) => a.toLowerCase() == ayAdi);
    if (ay >= 0) {
      return DateTime(int.parse(m.group(3)!), ay + 1, int.parse(m.group(1)!));
    }
  }
  final n = _noktaRegex.firstMatch(t);
  if (n != null) {
    return DateTime(
        int.parse(n.group(3)!), int.parse(n.group(2)!), int.parse(n.group(1)!));
  }
  return null;
}

/// "5 Mart 2026", "5 Mart 2026 - 8 Mart 2026", "5.3.2026" biçimlerini çözer.
DateTimeRange? tarihCoz(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final parcalar = s.split(RegExp(r'\s+-\s+'));
  final b = _tekTarih(parcalar.first);
  if (b == null) return null;
  final e = parcalar.length > 1 ? (_tekTarih(parcalar[1]) ?? b) : b;
  return DateTimeRange(start: b, end: e.isBefore(b) ? b : e);
}

String tarihYaz(DateTime d) => '${d.day} ${aylar[d.month - 1]} ${d.year}';

String aralikYaz(DateTime b, DateTime? e) =>
    (e == null || e == b) ? tarihYaz(b) : '${tarihYaz(b)} - ${tarihYaz(e)}';

String isoTarih(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Ekranda gösterim: "5 Mart 2026" veya "5 - 8 Mart 2026"
String tarihGoster(String? s) {
  final r = tarihCoz(s);
  if (r == null) return (s == null || s.isEmpty) ? '-' : s;
  if (r.start == r.end) return tarihYaz(r.start);
  if (r.start.month == r.end.month && r.start.year == r.end.year) {
    return '${r.start.day} - ${r.end.day} ${aylar[r.end.month - 1]} ${r.end.year}';
  }
  return aralikYaz(r.start, r.end);
}

List<Map<String, dynamic>> tarihSirali(List<Map<String, dynamic>> liste) {
  final far = DateTime(2100);
  final kopya = [...liste];
  kopya.sort((a, b) {
    final x = tarihCoz(a['tarih']?.toString())?.start ?? far;
    final y = tarihCoz(b['tarih']?.toString())?.start ?? far;
    return x.compareTo(y);
  });
  return kopya;
}

// ---------- Para ----------
double sayi(dynamic v) =>
    v is num ? v.toDouble() : (double.tryParse('$v'.replaceAll(',', '.')) ?? 0);

String para(num v) {
  final p = v.toStringAsFixed(2).split('.');
  final tam =
      p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '$tam,${p[1]} ₺';
}

// ---------- Yetki ----------
class Yetki {
  final String id, adSoyad, unvan, birim, rol;
  const Yetki({
    required this.id,
    required this.adSoyad,
    required this.unvan,
    required this.birim,
    required this.rol,
  });

  bool get admin => ustUnvanlar.contains(unvan) || rol == 'Admin';
  bool get yazabilir => admin || rol != 'Gönüllü';
  bool get gonullu => !yazabilir;

  /// RLS politikalarıyla aynı mantık: admin veya kendi biriminin kaydı.
  bool yonetebilir(Map<String, dynamic> f) {
    if (admin) return true;
    if (!yazabilir) return false;
    final s = (f['olusturan_unvan'] ?? '').toString();
    return s.isNotEmpty && (s == birim || s == unvan);
  }

  bool durumDegistirebilir(Map<String, dynamic> f) =>
      yonetebilir(f) || f['atanan_kisi_id']?.toString() == id;

  String get atayanEtiketi => unvan.isEmpty ? adSoyad : '$adSoyad ($unvan)';
  String get birimAdi => birim.isNotEmpty ? birim : unvan;

  static Future<Yetki?> yukle() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final p = await supabase
          .from('profiller')
          .select('ad, soyad, unvan, bagli_birim, yetki_seviyesi')
          .eq('id', user.id)
          .maybeSingle();
      return Yetki(
        id: user.id,
        adSoyad: tamAdGetir(p),
        unvan: (p?['unvan'] ?? '').toString(),
        birim: (p?['bagli_birim'] ?? '').toString(),
        rol: (p?['yetki_seviyesi'] ?? 'Gönüllü').toString(),
      );
    } catch (e) {
      debugPrint('Yetki yüklenemedi: $e');
      return Yetki(
          id: user.id, adSoyad: '', unvan: '', birim: '', rol: 'Gönüllü');
    }
  }
}
