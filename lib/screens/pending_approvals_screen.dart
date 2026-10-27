import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/ortak.dart';

class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  late Stream<List<Map<String, dynamic>>> _stream;
  Yetki? _yetki;
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _stream = supabase
        .from('faaliyetler')
        .stream(primaryKey: ['id'])
        .eq('onay_durumu', 'Bekliyor')
        .order('created_at');

    Yetki.yukle().then((y) {
      if (mounted) {
        setState(() {
          _yetki = y;
          _yukleniyor = false;
        });
      }
    });
  }

  Future<void> _islemYap(Map<String, dynamic> f, bool onay) async {
    try {
      if (onay) {
        await supabase
            .from('faaliyetler')
            .update({'onay_durumu': 'Onaylandı'}).eq('id', f['id']);

        if (f['atanan_kisi_id'] != null) {
          await supabase.functions.invoke(
            'gorev-bildirimi',
            body: {
              'hedefKullaniciId': f['atanan_kisi_id'],
              'faaliyetBaslik': f['baslik'],
              'tarih': f['tarih'],
              'birim': f['hedef_birim'] ?? 'Genel',
              'baslik': '✅ Göreviniz Onaylandı!'
            },
          );
        }
        if (mounted) {
          bildir(context, 'Faaliyet onaylandı ve yayına alındı.');
        }
      } else {
        final eminMi = await onayDialogu(context,
            baslik: 'Faaliyeti Reddet',
            mesaj: 'Bu faaliyet tamamen silinecek. Onaylıyor musunuz?');
        if (!eminMi) return;
        await supabase.from('faaliyetler').delete().eq('id', f['id']);
        if (mounted) {
          bildir(context, 'Faaliyet reddedildi ve silindi.', renk: Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        bildir(context, 'İşlem başarısız: $e', renk: Colors.orange);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Onay Bekleyen Faaliyetler',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }

          final liste = snapshot.data!.where((f) {
            if (_yetki?.admin ?? false) return true;
            return f['ilce_id']?.toString() == _yetki?.ilceId;
          }).toList();

          if (liste.isEmpty) {
            return const Center(
                child: Text('Onay bekleyen faaliyet yok.',
                    style: TextStyle(color: Colors.white54)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: liste.length,
            itemBuilder: (context, i) {
              final f = liste[i];
              return Card(
                color: AppColors.card,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(f['baslik']?.toString() ?? '',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'Ekleyen: ${f['olusturan_unvan']} • Tarih: ${f['tarih']} \nİlçe: ${Ilceler.ad(f['ilce_id'])}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon:
                              const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: () => _islemYap(f, false)),
                      IconButton(
                          icon: const Icon(Icons.check,
                              color: Colors.greenAccent),
                          onPressed: () => _islemYap(f, true)),
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
