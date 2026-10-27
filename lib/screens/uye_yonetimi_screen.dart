import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/ortak.dart';

class UyeYonetimiScreen extends StatefulWidget {
  const UyeYonetimiScreen({super.key});

  @override
  State<UyeYonetimiScreen> createState() => _UyeYonetimiScreenState();
}

class _UyeYonetimiScreenState extends State<UyeYonetimiScreen> {
  late final Stream<List<Map<String, dynamic>>> _stream;
  Yetki? _yetki;
  List<Map<String, dynamic>> _birimler = [];
  bool _sadeceBekleyen = true;
  String _ilceFiltre = 'tum';

  @override
  void initState() {
    super.initState();
    _stream = supabase.from('profiller').stream(primaryKey: ['id']).order('ad');
    _yukle();
  }

  Future<void> _yukle() async {
    final y = await Yetki.yukle();
    List<Map<String, dynamic>> b = [];
    try {
      b = List<Map<String, dynamic>>.from(await supabase
          .from('birimler')
          .select('id, ad, kategori, ilce_id')
          .order('sira'));
    } catch (e) {
      debugPrint('Birimler alınamadı: $e');
    }
    if (!mounted) return;
    setState(() {
      _yetki = y;
      _birimler = b;
    });
  }

  String _birimAd(dynamic id) {
    if (id == null) return '-';
    for (final b in _birimler) {
      if (b['id'].toString() == id.toString()) return b['ad'].toString();
    }
    return '-';
  }

  List<Map<String, dynamic>> _suz(List<Map<String, dynamic>> hepsi) {
    final y = _yetki;
    if (y == null) return [];
    return hepsi.where((p) {
      final pi = p['ilce_id']?.toString();
      if (!y.admin && pi != y.ilceId) return false;
      if (y.admin && _ilceFiltre != 'tum') {
        if (_ilceFiltre == 'il' ? pi != null : pi != _ilceFiltre) return false;
      }
      if (_sadeceBekleyen && p['onay_durumu'] == 'onaylandı') return false;
      return true;
    }).toList();
  }

  Color _onayRengi(String? o) => o == 'onaylandı'
      ? Colors.greenAccent
      : (o == 'reddedildi' ? Colors.redAccent : Colors.orangeAccent);

  Future<void> _duzenle(Map<String, dynamic> p) async {
    final y = _yetki!;
    final adCtrl = TextEditingController(text: p['ad']?.toString() ?? '');
    final soyadCtrl = TextEditingController(text: p['soyad']?.toString() ?? '');
    final telCtrl = TextEditingController(text: p['telefon']?.toString() ?? '');

    String ilceDeger = p['ilce_id']?.toString() ?? 'il';
    String? birimId =
        p['birim_id']?.toString() ?? p['talep_edilen_birim_id']?.toString();
    String yetkiSeviyesi = (p['yetki_seviyesi'] ?? 'Gönüllü').toString();
    bool ilceYon = p['ilce_yoneticisi'] == true;

    final yetkiSecenek =
        y.admin ? ['Gönüllü', 'İlçe', 'İl'] : ['Gönüllü', 'İlçe'];
    if (!yetkiSecenek.contains(yetkiSeviyesi)) yetkiSecenek.add(yetkiSeviyesi);

    List<Map<String, dynamic>> liste() {
      final ilce = ilceDeger == 'il' ? null : ilceDeger;
      final hamListe = _birimler.where((b) {
        if (b['ilce_id']?.toString() != ilce) return false;
        if (!y.admin && b['kategori'] == 'Yönetim') return false;

        final bAd = b['ad'].toString().trim();
        if (bAd.toLowerCase() == 'genel') return false;
        if (bAd.toLowerCase().contains('ilkokul')) return false;
        if (ilce != null && bAd.contains('Üniversite')) return false;
        return true;
      });

      final Map<String, Map<String, dynamic>> tekilListe = {};
      for (final b in hamListe) {
        final id = b['id']?.toString();
        if (id != null) {
          tekilListe[id] = b;
        }
      }

      final sonListe = tekilListe.values.toList();
      sonListe.sort((a, b) => a['ad'].toString().compareTo(b['ad'].toString()));
      return sonListe;
    }

    bool kaydediliyor = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final guvenliListe = liste();
          String? guvenliBirimId = birimId;

          if (guvenliBirimId != null &&
              !guvenliListe.any((b) => b['id'].toString() == guvenliBirimId)) {
            guvenliBirimId = null;
          }

          return AlertDialog(
            backgroundColor: kutuRengi,
            title: Text(tamAdGetir(p).isEmpty ? 'Üye' : tamAdGetir(p),
                style: const TextStyle(color: Colors.white, fontSize: 17)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: adCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: koyuInput(label: 'Ad', icon: Icons.person)),
                const SizedBox(height: 10),
                TextField(
                    controller: soyadCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: koyuInput(label: 'Soyad', icon: Icons.person)),
                const SizedBox(height: 10),
                TextField(
                    controller: telCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: koyuInput(label: 'Telefon', icon: Icons.phone)),
                const SizedBox(height: 14),
                if (y.admin)
                  DropdownButtonFormField<String>(
                    initialValue: ilceDeger,
                    isExpanded: true,
                    dropdownColor: AppColors.inputFill,
                    style: const TextStyle(color: Colors.white),
                    decoration: koyuInput(
                        label: 'İlçe / Teşkilat', icon: Icons.location_city),
                    items: [
                      const DropdownMenuItem(
                          value: 'il', child: Text('İl (Merkez)')),
                      ...Ilceler.liste.map((i) => DropdownMenuItem(
                          value: i['id'].toString(),
                          child: Text(i['ad'].toString()))),
                    ],
                    onChanged: (v) => setM(() {
                      ilceDeger = v ?? ilceDeger;
                      birimId = null;
                      if (ilceDeger == 'il') ilceYon = false;
                    }),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('İlçe: ${Ilceler.ad(p['ilce_id'])}',
                        style: const TextStyle(color: Colors.white70)),
                  ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey('b_$ilceDeger'),
                  initialValue: guvenliBirimId,
                  isExpanded: true,
                  dropdownColor: AppColors.inputFill,
                  style: const TextStyle(color: Colors.white),
                  decoration: koyuInput(
                      label: 'Atanacak Birim', icon: Icons.account_balance),
                  items: guvenliListe
                      .map((b) => DropdownMenuItem<String>(
                          value: b['id'].toString(),
                          child: Text(b['ad'].toString(),
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setM(() => birimId = v),
                ),
                if (p['talep_edilen_birim_id'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          'Talep ettiği birim: ${_birimAd(p['talep_edilen_birim_id'])}',
                          style: const TextStyle(
                              color: Colors.orangeAccent, fontSize: 12)),
                    ),
                  ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: yetkiSeviyesi,
                  isExpanded: true,
                  dropdownColor: AppColors.inputFill,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      koyuInput(label: 'Yetki Seviyesi', icon: Icons.security),
                  items: yetkiSecenek
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) =>
                      setM(() => yetkiSeviyesi = v ?? yetkiSeviyesi),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                      'Gönüllü: sadece görüntüler. İlçe/İl: kendi biriminin faaliyetlerini yönetir.',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ),
                if (y.admin)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.accent,
                    title: const Text('İlçe yöneticisi (İlçe Başkanı yetkisi)',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: const Text(
                        'Kendi ilçesindeki herkesi onaylar ve faaliyetleri yönetir',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                    value: ilceYon,
                    onChanged: ilceDeger == 'il'
                        ? null
                        : (v) => setM(() => ilceYon = v),
                  ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: kaydediliyor ? null : () => Navigator.pop(ctx),
                  child: const Text('İptal',
                      style: TextStyle(color: Colors.white54))),
              TextButton(
                  onPressed: kaydediliyor
                      ? null
                      : () async {
                          try {
                            await supabase
                                .from('profiller')
                                .update({'onay_durumu': 'reddedildi'}).eq(
                                    'id', p['id']);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                          } catch (e) {
                            debugPrint('Reddedilemedi: $e');
                            if (ctx.mounted) {
                              bildir(ctx, 'İşlem yapılamadı.',
                                  renk: Colors.red);
                            }
                          }
                        },
                  child: const Text('Reddet',
                      style: TextStyle(color: Colors.redAccent))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black),
                onPressed: kaydediliyor
                    ? null
                    : () async {
                        if (birimId == null) {
                          bildir(ctx, 'Lütfen bir birim seçin.',
                              renk: Colors.orange);
                          return;
                        }
                        setM(() => kaydediliyor = true);
                        try {
                          final veri = <String, dynamic>{
                            'ad': adCtrl.text.trim(),
                            'soyad': soyadCtrl.text.trim(),
                            'telefon': telCtrl.text.trim(),
                            'birim_id': birimId,
                            'yetki_seviyesi': yetkiSeviyesi,
                            'onay_durumu': 'onaylandı',
                          };
                          if (y.admin) {
                            veri['ilce_id'] =
                                ilceDeger == 'il' ? null : ilceDeger;
                            veri['ilce_yoneticisi'] = ilceYon;
                          }
                          final s = await supabase
                              .from('profiller')
                              .update(veri)
                              .eq('id', p['id'])
                              .select();
                          if (!ctx.mounted) return;
                          if (s.isEmpty) {
                            setM(() => kaydediliyor = false);
                            bildir(
                                ctx, 'Bu kullanıcıyı değiştirme yetkiniz yok.',
                                renk: Colors.orange);
                            return;
                          }
                          Navigator.pop(ctx);
                          if (mounted) {
                            bildir(context, 'Üye onaylandı ve güncellendi.');
                          }
                        } catch (e) {
                          debugPrint('Üye güncellenemedi: $e');
                          if (!ctx.mounted) return;
                          setM(() => kaydediliyor = false);
                          bildir(ctx,
                              'Güncellenemedi. Birim ilçeyle uyuşmuyor olabilir.',
                              renk: Colors.red);
                        }
                      },
                child: kaydediliyor
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Text('Onayla / Kaydet',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sil(Map<String, dynamic> p) async {
    final onay = await onayDialogu(context,
        baslik: 'Üyeyi Sil',
        mesaj:
            'Profil silinecek. (Giriş hesabı Supabase > Authentication bölümünden ayrıca kaldırılmalıdır.)');
    if (!onay) return;
    try {
      final s =
          await supabase.from('profiller').delete().eq('id', p['id']).select();
      if (!mounted) return;
      if (s.isEmpty) {
        bildir(context, 'Silme yetkiniz yok.', renk: Colors.orange);
      } else {
        bildir(context, 'Profil silindi.', renk: Colors.red);
      }
    } catch (e) {
      debugPrint('Üye silinemedi: $e');
      if (mounted) bildir(context, 'Silinemedi.', renk: Colors.red);
    }
  }

  Widget _chip(String etiket, bool secili, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(etiket),
          selected: secili,
          onSelected: (_) => onTap(),
          backgroundColor: AppColors.card,
          selectedColor: AppColors.secondary,
          labelStyle:
              TextStyle(color: secili ? AppColors.accent : Colors.white70),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final y = _yetki;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Üye Onayları & Yönetim',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: y == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : (!y.admin && !y.ilceAdmini)
              ? const Center(
                  child: Text('Bu ekran için yetkiniz yok.',
                      style: TextStyle(color: Colors.white54)))
              : Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(children: [
                        _chip('Onay Bekleyenler', _sadeceBekleyen,
                            () => setState(() => _sadeceBekleyen = true)),
                        _chip('Tüm Üyeler', !_sadeceBekleyen,
                            () => setState(() => _sadeceBekleyen = false)),
                      ]),
                    ),
                    if (y.admin)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: DropdownButtonFormField<String>(
                          value: _ilceFiltre,
                          isExpanded: true,
                          dropdownColor: AppColors.inputFill,
                          style: const TextStyle(color: Colors.white),
                          decoration: koyuInput(
                              label: 'İlçe / Teşkilat Filtresi',
                              icon: Icons.location_city),
                          items: [
                            const DropdownMenuItem(
                                value: 'tum', child: Text('Tüm Teşkilat')),
                            const DropdownMenuItem(
                                value: 'il', child: Text('İl (Merkez)')),
                            ...Ilceler.liste.map((i) => DropdownMenuItem(
                                value: i['id'].toString(),
                                child: Text(i['ad'].toString()))),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _ilceFiltre = v);
                          },
                        ),
                      ),
                    Expanded(
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _stream,
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return const Center(
                                child: Text('Üyeler alınamadı.',
                                    style: TextStyle(color: Colors.redAccent)));
                          }
                          if (!snap.hasData) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.accent));
                          }
                          final liste = _suz(snap.data!);
                          if (liste.isEmpty) {
                            return Center(
                                child: Text(
                                    _sadeceBekleyen
                                        ? 'Onay bekleyen üye yok.'
                                        : 'Üye bulunamadı.',
                                    style: const TextStyle(
                                        color: Colors.white54)));
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: liste.length,
                            itemBuilder: (context, i) {
                              final p = liste[i];
                              final onay =
                                  (p['onay_durumu'] ?? 'bekliyor').toString();
                              final renk = _onayRengi(onay);
                              final isSelf = p['id'].toString() == y.id;
                              final ad = tamAdGetir(p);
                              return Card(
                                color: AppColors.card,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                        color: renk.withValues(alpha: 0.35))),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                          child: Text(
                                              ad.isEmpty ? 'İsimsiz' : ad,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              color:
                                                  renk.withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: Text(
                                              onay == 'onaylandı'
                                                  ? 'Onaylı'
                                                  : (onay == 'reddedildi'
                                                      ? 'Reddedildi'
                                                      : 'Bekliyor'),
                                              style: TextStyle(
                                                  color: renk, fontSize: 11)),
                                        ),
                                      ]),
                                      const SizedBox(height: 6),
                                      Text('🗺️ ${Ilceler.ad(p['ilce_id'])}',
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12)),
                                      Text(
                                          '🏢 Birim: ${_birimAd(p['birim_id'])}  •  Yetki: ${p['yetki_seviyesi'] ?? 'Gönüllü'}${p['ilce_yoneticisi'] == true ? '  •  İlçe Yöneticisi' : ''}',
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12)),
                                      if (p['talep_edilen_birim_id'] != null &&
                                          p['birim_id'] == null)
                                        Text(
                                            '📝 Talep: ${_birimAd(p['talep_edilen_birim_id'])}',
                                            style: const TextStyle(
                                                color: Colors.orangeAccent,
                                                fontSize: 12)),
                                      if ((p['telefon'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Text('📞 ${p['telefon']}',
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12)),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          if (y.admin && !isSelf)
                                            IconButton(
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.redAccent,
                                                    size: 20),
                                                onPressed: () => _sil(p)),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.accent,
                                                foregroundColor: Colors.black),
                                            onPressed: () => _duzenle(p),
                                            icon: Icon(
                                                onay == 'onaylandı'
                                                    ? Icons.edit
                                                    : Icons.check,
                                                size: 18),
                                            label: Text(
                                                onay == 'onaylandı'
                                                    ? 'Düzenle'
                                                    : 'Onayla / Ata',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ],
                                      ),
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
