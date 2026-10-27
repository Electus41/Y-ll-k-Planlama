import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/faaliyet_servisi.dart';
import '../core/ortak.dart';
import '../widgets/faaliyet_form_dialog.dart';
import '../widgets/faaliyet_karti.dart';
import 'faaliyet_detay_screen.dart';

/// Faaliyet bu birimle eşleşiyor mu? (id varsa id'ye, yoksa eski ad kaydına bakar)
bool birimEslesir(Map<String, dynamic> f, Map<String, dynamic> b,
    {required bool hedef}) {
  final id = b['id'].toString();
  final ad = b['ad'];
  if (hedef) {
    final h = f['hedef_birim_id'];
    return h != null ? h.toString() == id : f['hedef_birim'] == ad;
  }
  final s = f['sorumlu_birim_id'];
  return s != null ? s.toString() == id : f['olusturan_unvan'] == ad;
}

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  late final Stream<List<Map<String, dynamic>>> _birimStream;
  late final Stream<List<Map<String, dynamic>>> _faaliyetStream;
  Yetki? _yetki;
  String _arama = '';

  @override
  void initState() {
    super.initState();
    _birimStream =
        supabase.from('birimler').stream(primaryKey: ['id']).order('sira');
    _faaliyetStream = supabase.from('faaliyetler').stream(primaryKey: ['id']);
    Yetki.yukle().then((y) {
      if (mounted) setState(() => _yetki = y);
    });
  }

  Widget _rozet(int sayi, Color renk, String ipucu) {
    return Tooltip(
      message: ipucu,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: renk.withValues(alpha: 0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 8, color: renk),
          const SizedBox(width: 4),
          Text('$sayi',
              style: TextStyle(
                  color: renk, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Birimlere Göre Faaliyetler',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_yetki?.admin ?? false)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Birimleri Yönet',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BirimYonetimiScreen())),
            ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _birimStream,
        builder: (context, birimSnap) {
          if (birimSnap.hasError) {
            return const Center(
                child: Text('Birimler alınamadı.',
                    style: TextStyle(color: Colors.redAccent)));
          }
          if (!birimSnap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }

          // BAŞKANLARI BURADAN FİLTRELİYORUZ
          final birimler = birimSnap.data!
              .where((b) => !b['ad'].toString().contains('Başkan'))
              .toList();

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _faaliyetStream,
            builder: (context, faalSnap) {
              if (!faalSnap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.accent));
              }
              final faaliyetler = faalSnap.data!;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          koyuInput(label: 'Birim ara...', icon: Icons.search),
                      onChanged: (v) =>
                          setState(() => _arama = v.trim().toLowerCase()),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: birimKategorileri.map((kategori) {
                        final liste = birimler
                            .where((b) =>
                                b['kategori'] == kategori &&
                                b['ad']
                                    .toString()
                                    .toLowerCase()
                                    .contains(_arama))
                            .toList();
                        if (liste.isEmpty) return const SizedBox.shrink();
                        final hedefMi = kategori == komisyonKategorisi;

                        return Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: Text(kategori,
                                style: const TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            initiallyExpanded: true,
                            iconColor: AppColors.accent,
                            collapsedIconColor: Colors.white54,
                            children: liste.map((birim) {
                              final fl = faaliyetler
                                  .where((f) =>
                                      birimEslesir(f, birim, hedef: hedefMi))
                                  .toList();
                              int say(String d) =>
                                  fl.where((f) => f['durum'] == d).length;

                              return Card(
                                color: AppColors.card,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.05))),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  title: Text(birim['ad'].toString(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text('Toplam ${fl.length}',
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12)),
                                        _rozet(
                                            say('Yapılacak'),
                                            Colors.lightBlueAccent,
                                            'Yapılacak'),
                                        _rozet(say('Yapılıyor'),
                                            Colors.orangeAccent, 'Yapılıyor'),
                                        _rozet(say('Tamamlandı'),
                                            Colors.greenAccent, 'Tamamlandı'),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios,
                                      color: Colors.white38, size: 16),
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              BirimDetayScreen(birim: birim))),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ======================= BİRİM DETAY =======================
class BirimDetayScreen extends StatefulWidget {
  final Map<String, dynamic> birim;
  const BirimDetayScreen({super.key, required this.birim});

  @override
  State<BirimDetayScreen> createState() => _BirimDetayScreenState();
}

class _BirimDetayScreenState extends State<BirimDetayScreen> {
  late final Stream<List<Map<String, dynamic>>> _stream;
  late bool _hedefGorunum;
  String _durumFiltresi = 'Tümü';
  Yetki? _yetki;

  @override
  void initState() {
    super.initState();
    _stream = supabase.from('faaliyetler').stream(primaryKey: ['id']);
    _hedefGorunum = widget.birim['kategori'] == komisyonKategorisi;
    Yetki.yukle().then((y) {
      if (mounted) setState(() => _yetki = y);
    });
  }

  @override
  Widget build(BuildContext context) {
    final birim = widget.birim;
    final komisyon = birim['kategori'] == komisyonKategorisi;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(birim['ad'].toString(),
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: (_yetki?.yazabilir ?? false)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              onPressed: () => faaliyetFormuAc(context,
                  varsayilanHedefId: komisyon ? birim['id'].toString() : null),
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('Faaliyet Ekle',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Hedef Olduğu')),
                ButtonSegment(value: false, label: Text('Sorumlu Olduğu')),
              ],
              selected: {_hedefGorunum},
              onSelectionChanged: (s) =>
                  setState(() => _hedefGorunum = s.first),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['Tümü', ...durumlar].map((d) {
                final s = _durumFiltresi == d;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(d),
                    selected: s,
                    selectedColor: AppColors.secondary,
                    backgroundColor: AppColors.card,
                    labelStyle:
                        TextStyle(color: s ? AppColors.accent : Colors.white70),
                    onSelected: (_) => setState(() => _durumFiltresi = d),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent));
                }
                var liste = snap.data!
                    .where((f) => birimEslesir(f, birim, hedef: _hedefGorunum))
                    .toList();
                if (_durumFiltresi != 'Tümü') {
                  liste =
                      liste.where((f) => f['durum'] == _durumFiltresi).toList();
                }
                liste = tarihSirali(liste);

                if (liste.isEmpty) {
                  return const Center(
                      child: Text('Bu görünümde faaliyet bulunamadı.',
                          style: TextStyle(color: Colors.white54)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: liste.length,
                  itemBuilder: (context, i) {
                    final f = liste[i];
                    return FaaliyetKarti(
                      f: f,
                      yetki: _yetki,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => FaaliyetDetayScreen(
                                  faaliyetId: f['id'].toString()))),
                      onDuzenle: () => faaliyetFormuAc(context, mevcut: f),
                      onSil: () => FaaliyetServisi.sil(context, f),
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

// ======================= BİRİM YÖNETİMİ (sadece admin) =======================
class BirimYonetimiScreen extends StatefulWidget {
  const BirimYonetimiScreen({super.key});

  @override
  State<BirimYonetimiScreen> createState() => _BirimYonetimiScreenState();
}

class _BirimYonetimiScreenState extends State<BirimYonetimiScreen> {
  late final Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream =
        supabase.from('birimler').stream(primaryKey: ['id']).order('sira');
  }

  Future<void> _modalAc({Map<String, dynamic>? mevcut}) async {
    final adCtrl = TextEditingController(text: mevcut?['ad']?.toString() ?? '');
    final aciklamaCtrl =
        TextEditingController(text: mevcut?['aciklama']?.toString() ?? '');
    final siraCtrl = TextEditingController(text: '${mevcut?['sira'] ?? ''}');
    String kategori = birimKategorileri.contains(mevcut?['kategori'])
        ? mevcut!['kategori'] as String
        : 'İcra Birimi';

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          backgroundColor: kutuRengi,
          title: Text(
              mevcut == null ? 'Yeni Birim / Komisyon' : 'Birimi Düzenle',
              style: const TextStyle(color: Colors.white, fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: adCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      koyuInput(label: 'Birim Adı', icon: Icons.groups)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kategori,
                isExpanded: true,
                dropdownColor: AppColors.inputFill,
                style: const TextStyle(color: Colors.white),
                decoration: koyuInput(label: 'Kategori', icon: Icons.category),
                items: birimKategorileri
                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                    .toList(),
                onChanged: (v) => setM(() => kategori = v ?? kategori),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: aciklamaCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: koyuInput(
                      label: 'Açıklama (opsiyonel)', icon: Icons.notes)),
              const SizedBox(height: 12),
              TextField(
                  controller: siraCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      koyuInput(label: 'Sıra (küçük önce)', icon: Icons.sort)),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal',
                    style: TextStyle(color: Colors.white54))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (kaydet != true) return;
    final yeniAd = adCtrl.text.trim();
    if (yeniAd.isEmpty) return;

    final veri = <String, dynamic>{
      'ad': yeniAd,
      'kategori': kategori,
      'aciklama': aciklamaCtrl.text.trim(),
      'sira': int.tryParse(siraCtrl.text.trim()) ?? 999,
    };

    try {
      if (mevcut == null) {
        await supabase.from('birimler').insert(veri);
      } else {
        await supabase.from('birimler').update(veri).eq('id', mevcut['id']);
        final eskiAd = mevcut['ad'].toString();
        if (eskiAd != yeniAd) {
          // Ad değiştiyse metin olarak saklanan kayıtları da güncelle
          await supabase.from('faaliyetler').update({'hedef_birim': yeniAd}).eq(
              'hedef_birim_id', mevcut['id']);
          await supabase.from('faaliyetler').update(
              {'olusturan_unvan': yeniAd}).eq('sorumlu_birim_id', mevcut['id']);
          for (final t in [
            ['profiller', 'bagli_birim'],
            ['profiller', 'unvan'],
            ['toplanti_notlari', 'olusturan_birim'],
          ]) {
            await supabase.from(t[0]).update({t[1]: yeniAd}).eq(t[1], eskiAd);
          }
        }
      }
    } catch (e) {
      debugPrint('Birim kaydedilemedi: $e');
      if (mounted) {
        bildir(context, 'Birim kaydedilemedi. Yetkiniz olmayabilir.',
            renk: Colors.red);
      }
    }
  }

  Future<void> _sil(Map<String, dynamic> b) async {
    try {
      final kullanan = await supabase
          .from('faaliyetler')
          .select('id')
          .or('hedef_birim_id.eq.${b['id']},sorumlu_birim_id.eq.${b['id']}')
          .limit(1);
      if (kullanan.isNotEmpty) {
        if (mounted) {
          bildir(context,
              'Bu birime bağlı faaliyetler var. Önce onları başka birime taşıyın.',
              renk: Colors.orange);
        }
        return;
      }
      if (!mounted) return;
      final onay = await onayDialogu(context,
          baslik: 'Birimi Sil', mesaj: '"${b['ad']}" silinsin mi?');
      if (!onay) return;
      await supabase.from('birimler').delete().eq('id', b['id']);
    } catch (e) {
      debugPrint('Birim silinemedi: $e');
      if (mounted) bildir(context, 'Silinemedi.', renk: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Birimleri Yönet',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        onPressed: () => _modalAc(),
        icon: const Icon(Icons.add),
        label: const Text('Yeni Birim',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }
          final birimler = snap.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: birimler.length,
            itemBuilder: (context, i) {
              final b = birimler[i];
              return Card(
                color: AppColors.card,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white12)),
                child: ListTile(
                  title: Text(b['ad'].toString(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      [b['kategori'], b['aciklama']]
                          .where((e) => e != null && e.toString().isNotEmpty)
                          .join(' • '),
                      style: const TextStyle(
                          color: Colors.orangeAccent, fontSize: 12)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.blueAccent, size: 20),
                        onPressed: () => _modalAc(mevcut: b)),
                    IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.redAccent, size: 20),
                        onPressed: () => _sil(b)),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
