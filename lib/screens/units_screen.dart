import 'package:flutter/material.dart';
import '../core/constants.dart';

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  late Stream<List<Map<String, dynamic>>> _birimStream;
  late Stream<List<Map<String, dynamic>>> _faaliyetStream;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _birimStream =
        supabase.from('birimler').stream(primaryKey: ['id']).order('sira');
    _faaliyetStream = supabase.from('faaliyetler').stream(primaryKey: ['id']);
    _adminKontrolu();
  }

  Future<void> _adminKontrolu() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final res = await supabase
          .from('profiller')
          .select('unvan')
          .eq('id', user.id)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _isAdmin = (res['unvan'] == 'İl Başkanı' ||
              res['unvan'] == 'Teşkilatlanma Başkanı');
        });
      }
    }
  }

  Future<void> _birimModalAc({Map<String, dynamic>? mevcutBirim}) async {
    final adCtrl = TextEditingController(text: mevcutBirim?['ad'] ?? '');
    final aciklamaCtrl =
        TextEditingController(text: mevcutBirim?['aciklama'] ?? '');
    String seciliKategori = mevcutBirim?['kategori'] ?? 'İcra Birimi';
    final guncellemeMi = mevcutBirim != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF161C1A),
          title: Text(guncellemeMi ? 'Birimi Düzenle' : 'Yeni Birim / Komisyon',
              style: const TextStyle(color: Colors.white, fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: adCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: 'Birim Adı',
                        labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue:
                      seciliKategori, // 'value' yerine 'initialValue' kullanıldı
                  dropdownColor: const Color(0xFF1E292B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Birim Kategorisi',
                      labelStyle: TextStyle(color: Colors.orangeAccent)),
                  items: ['Yönetim', 'İcra Birimi', 'Hedef Kitle Komisyonu']
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setModalState(() => seciliKategori = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: aciklamaCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: 'Açıklama',
                        labelStyle: TextStyle(color: Colors.white54))),
              ],
            ),
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
              onPressed: () async {
                if (adCtrl.text.trim().isEmpty) {
                  return;
                }

                final veri = {
                  'ad': adCtrl.text.trim(),
                  'kategori': seciliKategori,
                  'aciklama': aciklamaCtrl.text.trim()
                };

                if (guncellemeMi) {
                  await supabase
                      .from('birimler')
                      .update(veri)
                      .eq('id', mevcutBirim['id']);
                } else {
                  await supabase.from('birimler').insert(veri);
                }

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Kaydet',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
          if (_isAdmin)
            IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Birimleri Yönet',
                onPressed: () => _birimModalAc()),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _birimStream,
        builder: (context, birimSnap) {
          if (!birimSnap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }
          final birimler = birimSnap.data!;

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _faaliyetStream,
            builder: (context, faalSnap) {
              if (!faalSnap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.accent));
              }
              final faaliyetler = faalSnap.data!;
              final kategoriler = [
                'Yönetim',
                'İcra Birimi',
                'Hedef Kitle Komisyonu'
              ];

              return ListView(
                padding: const EdgeInsets.all(16),
                children: kategoriler.map((kategori) {
                  final kategoriBirimleri =
                      birimler.where((b) => b['kategori'] == kategori).toList();

                  if (kategoriBirimleri.isEmpty) {
                    return const SizedBox.shrink();
                  }

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
                      children: kategoriBirimleri.map((birim) {
                        int todo = 0, doing = 0, done = 0;
                        List<Map<String, dynamic>> biriminFaaliyetleri = [];

                        for (var f in faaliyetler) {
                          bool matches = (f['hedef_birim_id'] == birim['id'] ||
                                  f['sorumlu_birim_id'] == birim['id']) ||
                              (f['hedef_birim'] == birim['ad'] ||
                                  f['olusturan_unvan'] == birim['ad']);

                          if (matches) {
                            biriminFaaliyetleri.add(f);
                            if (f['durum'] == 'Yapılacak') {
                              todo++;
                            } else if (f['durum'] == 'Yapılıyor') {
                              doing++;
                            } else if (f['durum'] == 'Tamamlandı') {
                              done++;
                            }
                          }
                        }

                        return Card(
                          color: AppColors.card,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.05))),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            title: Text(birim['ad'],
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  _rozet(todo.toString(),
                                      Colors.lightBlueAccent, 'Yapılacak'),
                                  const SizedBox(width: 8),
                                  _rozet(doing.toString(), Colors.orangeAccent,
                                      'Yapılıyor'),
                                  const SizedBox(width: 8),
                                  _rozet(done.toString(), Colors.greenAccent,
                                      'Tamamlandı'),
                                ],
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios,
                                color: Colors.white38, size: 16),
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => BirimDetayScreen(
                                          birim: birim,
                                          faaliyetler: biriminFaaliyetleri)));
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }

  Widget _rozet(String sayi, Color renk, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: renk.withValues(
                    alpha: 0.5)) // 'BorderSide' yerine 'Border.all' kullanıldı
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: renk),
            const SizedBox(width: 4),
            Text(sayi,
                style: TextStyle(
                    color: renk, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class BirimDetayScreen extends StatelessWidget {
  final Map<String, dynamic> birim;
  final List<Map<String, dynamic>> faaliyetler;

  const BirimDetayScreen(
      {super.key, required this.birim, required this.faaliyetler});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(birim['ad'],
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: faaliyetler.isEmpty
          ? const Center(
              child: Text('Bu birime ait faaliyet bulunamadı.',
                  style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: faaliyetler.length,
              itemBuilder: (context, index) {
                final f = faaliyetler[index];
                return Card(
                  color: AppColors.card,
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1))),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Chip(
                          label: Text(f['durum'] ?? 'Yapılacak',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                          backgroundColor: f['durum'] == 'Tamamlandı'
                              ? Colors.green.shade800
                              : (f['durum'] == 'Yapılıyor'
                                  ? Colors.orange.shade800
                                  : Colors.blue.shade800),
                        ),
                        const SizedBox(height: 8),
                        Text(f['baslik'] ?? '',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 8),
                        Text('📅 Tarih: ${f['tarih'] ?? '-'}',
                            style: const TextStyle(color: Colors.white70)),
                        Text('📌 Öncelik: ${f['oncelik'] ?? 'Normal'}',
                            style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text('✍️ Atayan: ${f['atayan_ad'] ?? '-'}',
                            style: const TextStyle(
                                color: AppColors.accent, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
