import 'package:flutter/material.dart';
import '../core/constants.dart';

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  Future<void> _birimModalAc({Map<String, dynamic>? mevcutBirim}) async {
    final adCtrl = TextEditingController(text: mevcutBirim?['ad'] ?? '');
    final aciklamaCtrl =
        TextEditingController(text: mevcutBirim?['aciklama'] ?? '');
    final guncellemeMi = mevcutBirim != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161C1A),
        title: Text(
            guncellemeMi ? 'Birimi Düzenle' : 'Yeni Birim / Komisyon Ekle',
            style: const TextStyle(color: Colors.white, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: adCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Birim Adı (Örn: Lise Komisyonu)',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: aciklamaCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Görev Tanımı / Açıklama (Opsiyonel)',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('İptal', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black),
            onPressed: () async {
              if (adCtrl.text.trim().isEmpty) return;
              try {
                final Map<String, dynamic> veri = {'ad': adCtrl.text.trim()};
                if (aciklamaCtrl.text.trim().isNotEmpty) {
                  veri['aciklama'] = aciklamaCtrl.text.trim();
                }

                if (guncellemeMi) {
                  await supabase.from('birimler').update(
                      {'ad': adCtrl.text.trim()}).eq('id', mevcutBirim['id']);
                } else {
                  try {
                    await supabase.from('birimler').insert(veri);
                  } catch (_) {
                    // Tabloda 'aciklama' sütunu yoksa sadece 'ad' ile ekle
                    await supabase
                        .from('birimler')
                        .insert({'ad': adCtrl.text.trim()});
                  }
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                setState(() {});
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('İşlem hatası: $e'),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text('Kaydet',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _birimSil(dynamic id) async {
    final onay = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF161C1A),
            title:
                const Text('Birimi Sil', style: TextStyle(color: Colors.white)),
            content: const Text('Bu birimi silmek istediğinize emin misiniz?',
                style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('İptal',
                      style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sil', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (onay) {
      await supabase.from('birimler').delete().eq('id', id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Genç İHH Teşkilat Birimleri',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        onPressed: () => _birimModalAc(),
        icon: const Icon(Icons.add),
        label: const Text('Yeni Birim',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('birimler')
            .stream(primaryKey: ['id']).order('created_at'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Hata: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent)));
          }
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }

          final birimler = snapshot.data!;
          if (birimler.isEmpty) {
            return const Center(
                child: Text('Henüz kayıtlı birim bulunmuyor.',
                    style: TextStyle(color: Colors.white54)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: birimler.length,
            itemBuilder: (context, index) {
              final b = birimler[index];
              return Card(
                color: AppColors.card,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.secondary,
                    child: Icon(Icons.groups, color: AppColors.accent),
                  ),
                  title: Text(b['ad'] ?? '',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: b['aciklama'] != null &&
                          b['aciklama'].toString().isNotEmpty
                      ? Text(b['aciklama'],
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.blueAccent, size: 20),
                          onPressed: () => _birimModalAc(mevcutBirim: b)),
                      IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.redAccent, size: 20),
                          onPressed: () => _birimSil(b['id'])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
