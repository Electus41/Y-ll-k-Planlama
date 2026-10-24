import 'package:flutter/material.dart';
import '../core/constants.dart';

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  InputDecoration _koyuInputDekorasyonu({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF1F2624),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  Future<void> _birimSil(String id) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF161C1A),
            title: const Text('Silmek İstediğinize Emin Misiniz?',
                style: TextStyle(color: Colors.white)),
            content: const Text('Bu birim tamamen silinecektir.',
                style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('İptal',
                      style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  onPressed: () => Navigator.pop(context, true),
                  child:
                      const Text('Sil', style: TextStyle(color: Colors.white))),
            ],
          ),
        ) ??
        false;
    if (confirm) {
      await supabase.from('birimler').delete().eq('id', id);
      if (mounted) setState(() {});
    }
  }

  void _birimEkleModalAc({Map<String, dynamic>? mevcutBirim}) {
    final adController = TextEditingController(text: mevcutBirim?['ad'] ?? '');
    final aciklamaController =
        TextEditingController(text: mevcutBirim?['aciklama'] ?? '');
    bool isUpdate = mevcutBirim != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161C1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 24,
            right: 24,
            top: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isUpdate ? 'Birimi Düzenle' : 'Yeni Teşkilat Birimi Ekle',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(
                  controller: adController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _koyuInputDekorasyonu(
                      hint: 'Birim Adı (Örn: Ar-Ge Komisyonu)')),
              const SizedBox(height: 16),
              TextField(
                  controller: aciklamaController,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      _koyuInputDekorasyonu(hint: 'Birim Açıklaması / Görevi'),
                  maxLines: 3),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('İptal',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 14))),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF69F0AE),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14)),
                    onPressed: () async {
                      if (adController.text.isNotEmpty) {
                        try {
                          if (isUpdate) {
                            await supabase.from('birimler').update({
                              'ad': adController.text.trim(),
                              'aciklama': aciklamaController.text.trim()
                            }).eq('id', mevcutBirim['id']);
                          } else {
                            await supabase.from('birimler').insert({
                              'ad': adController.text.trim(),
                              'aciklama': aciklamaController.text.trim()
                            });
                          }
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Hata: $e'),
                              backgroundColor: Colors.red));
                        }
                      }
                    },
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text('Kaydet',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121816),
      appBar: AppBar(
          title: const Text('Kocaeli Teşkilat Birimleri',
              style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1B4D3E),
          iconTheme: const IconThemeData(color: Colors.white)),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('birimler')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .map((maps) => List<Map<String, dynamic>>.from(maps)),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF69F0AE)));
          final birimler = snapshot.data!;
          if (birimler.isEmpty)
            return const Center(
                child: Text(
                    'Henüz kayıtlı birim bulunmuyor. Sağ alt köşedeki butondan ekleyebilirsiniz.',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                    textAlign: TextAlign.center));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: birimler.length,
            itemBuilder: (context, index) {
              final birim = birimler[index];
              return Card(
                color: const Color(0xFF1A2220),
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.lightBlueAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.group,
                          color: Colors.lightBlueAccent, size: 28)),
                  title: Text(birim['ad'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16)),
                  subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(birim['aciklama'] ?? 'Açıklama girilmemiş',
                          style: const TextStyle(color: Colors.white54))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.blueAccent, size: 20),
                          onPressed: () =>
                              _birimEkleModalAc(mevcutBirim: birim)),
                      IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.redAccent, size: 20),
                          onPressed: () => _birimSil(birim['id'].toString())),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF69F0AE),
          foregroundColor: Colors.black,
          onPressed: () => _birimEkleModalAc(),
          child: const Icon(Icons.add)),
    );
  }
}
