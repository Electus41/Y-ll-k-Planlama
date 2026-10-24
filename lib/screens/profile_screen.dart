import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profil;
  bool _yukleniyor = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _profilGetir();
  }

  Future<void> _profilGetir() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('profiller')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _profil = data ??
              {
                'ad': user.userMetadata?['ad'] ?? '',
                'soyad': user.userMetadata?['soyad'] ?? '',
                'unvan': user.userMetadata?['unvan'] ?? 'Yönetici',
                'telefon': user.userMetadata?['telefon'] ?? '-',
                'email': user.email ?? '',
              };

          final unvan = _profil?['unvan']?.toString() ?? '';
          _isAdmin =
              (unvan == 'İl Başkanı' || unvan == 'Teşkilatlanma Başkanı');
          _yukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _yukleniyor = false);
      }
    }
  }

  // Cihazın bildirim kimliğini Supabase'e kaydeder
  Future<void> _oneSignalCihazKaydet() async {
    try {
      final onesignalId = OneSignal.User.pushSubscription.id;
      if (onesignalId != null && onesignalId.isNotEmpty) {
        final user = supabase.auth.currentUser;
        if (user != null) {
          await supabase
              .from('profiller')
              .update({'onesignal_id': onesignalId}).eq('id', user.id);
          setState(() {
            _profil?['onesignal_id'] = onesignalId;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Bildirimler başarıyla aktifleştirildi!'),
                backgroundColor: Colors.green));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'OneSignal ID alınamadı. Bildirim izinlerini kontrol edin.'),
              backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _kullaniciSil(String id) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF161C1A),
            title: const Text('Kullanıcıyı Sil',
                style: TextStyle(color: Colors.white)),
            content: const Text(
                'Bu kullanıcıyı silmek istediğinize emin misiniz?',
                style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('İptal',
                      style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sil', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await supabase.from('profiller').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Kullanıcı sistemden silindi.'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _baskaKullaniciDuzenleModal(
      Map<String, dynamic> kullanici) async {
    final adCtrl = TextEditingController(text: kullanici['ad'] ?? '');
    final soyadCtrl = TextEditingController(text: kullanici['soyad'] ?? '');
    final unvanCtrl = TextEditingController(text: kullanici['unvan'] ?? '');
    final telCtrl = TextEditingController(text: kullanici['telefon'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161C1A),
        title: const Text('Kullanıcı Bilgilerini Güncelle',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: adCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Ad',
                      labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 10),
              TextField(
                  controller: soyadCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Soyad',
                      labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 10),
              TextField(
                  controller: unvanCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Kurumsal Unvan',
                      labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 10),
              TextField(
                  controller: telCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Telefon',
                      labelStyle: TextStyle(color: Colors.white54))),
            ],
          ),
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
              try {
                await supabase.from('profiller').update({
                  'ad': adCtrl.text.trim(),
                  'soyad': soyadCtrl.text.trim(),
                  'unvan': unvanCtrl.text.trim(),
                  'telefon': telCtrl.text.trim(),
                }).eq('id', kullanici['id']);

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Kullanıcı başarıyla güncellendi!'),
                    backgroundColor: Colors.green));
              } catch (e) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Güncelleme reddedildi (Supabase yetkisi engelliyor olabilir).'),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text('Güncelle',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _profilDuzenleModal() async {
    final adCtrl = TextEditingController(text: _profil?['ad'] ?? '');
    final soyadCtrl = TextEditingController(text: _profil?['soyad'] ?? '');
    final unvanCtrl = TextEditingController(text: _profil?['unvan'] ?? '');
    final telCtrl = TextEditingController(text: _profil?['telefon'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161C1A),
        title: const Text('Profil Bilgilerini Güncelle',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: adCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Ad',
                      labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 10),
              TextField(
                  controller: soyadCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Soyad',
                      labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 10),
              TextField(
                  controller: unvanCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Kurumsal Unvan',
                      labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 10),
              TextField(
                  controller: telCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Telefon',
                      labelStyle: TextStyle(color: Colors.white54))),
            ],
          ),
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
              final user = supabase.auth.currentUser;
              if (user == null) return;
              await supabase.from('profiller').upsert({
                'id': user.id,
                'ad': adCtrl.text.trim(),
                'soyad': soyadCtrl.text.trim(),
                'unvan': unvanCtrl.text.trim(),
                'telefon': telCtrl.text.trim(),
                'email': user.email,
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _profilGetir();
            },
            child: const Text('Güncelle',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _cikisYap() async {
    try {
      OneSignal.logout();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('beni_hatirla', false);
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tamAd = '${_profil?['ad'] ?? ''} ${_profil?['soyad'] ?? ''}'.trim();
    final basHarf = tamAd.isNotEmpty ? tamAd[0].toUpperCase() : 'Y';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yönetici Profili',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
              icon: const Icon(Icons.edit, color: AppColors.accent),
              onPressed: _profilDuzenleModal),
        ],
      ),
      body: _yukleniyor
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.secondary,
                    child: Text(basHarf,
                        style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent)),
                  ),
                  const SizedBox(height: 16),
                  Text(tamAd.isEmpty ? 'İsimsiz Yönetici' : tamAd,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      _profil?['unvan']?.toString().isNotEmpty == true
                          ? _profil!['unvan']
                          : 'Teşkilat Yöneticisi',
                      style: const TextStyle(
                          color: AppColors.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _bilgiSatiri(Icons.email_outlined, 'E-Posta Adresi',
                      supabase.auth.currentUser?.email ?? '-'),
                  const SizedBox(height: 12),
                  _bilgiSatiri(
                      Icons.phone_outlined,
                      'Telefon Numarası',
                      _profil?['telefon']?.toString().isNotEmpty == true
                          ? _profil!['telefon']
                          : 'Belirtilmedi'),
                  const SizedBox(height: 12),

                  // OneSignal Bildirim Satırı (Tıklanabilir yapıldı)
                  GestureDetector(
                    onTap: _oneSignalCihazKaydet,
                    child: _bilgiSatiri(
                      Icons.notifications_active_outlined,
                      'Anlık Bildirim Durumu',
                      _profil?['onesignal_id'] != null
                          ? 'Aktif (Cihaz Eşleşti)'
                          : 'Bekleniyor (Aktifleştirmek İçin Tıklayın)',
                    ),
                  ),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _cikisYap,
                      icon: const Icon(Icons.logout),
                      label: const Text('Oturumu Kapat',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  if (_isAdmin) ...[
                    const SizedBox(height: 40),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    const Text('Teşkilat Üyeleri',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: supabase
                          .from('profiller')
                          .stream(primaryKey: ['id'])
                          .order('ad')
                          .map((maps) => List<Map<String, dynamic>>.from(maps)),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.accent));
                        }
                        final profiller = snapshot.hasData
                            ? snapshot.data!
                            : <Map<String, dynamic>>[];
                        if (profiller.isEmpty)
                          return const Text('Kayıtlı üye bulunamadı.',
                              style: TextStyle(color: Colors.white54));

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: profiller.length,
                          itemBuilder: (context, index) {
                            final p = profiller[index];
                            final pId = p['id'].toString();
                            final uyeAdSoyad =
                                '${p['ad'] ?? ''} ${p['soyad'] ?? ''}'.trim();
                            final uyeUnvan = p['unvan']?.toString() ?? 'Üye';
                            final isSelf = pId == supabase.auth.currentUser?.id;

                            return Card(
                              color: AppColors.card,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                title: Text(
                                    uyeAdSoyad.isEmpty ? 'İsimsiz' : uyeAdSoyad,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(uyeUnvan,
                                    style:
                                        const TextStyle(color: Colors.white70)),
                                trailing: isSelf
                                    ? const Text('Sen',
                                        style: TextStyle(
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.bold))
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blueAccent,
                                                size: 20),
                                            onPressed: () =>
                                                _baskaKullaniciDuzenleModal(p),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.redAccent,
                                                size: 20),
                                            onPressed: () => _kullaniciSil(pId),
                                          ),
                                        ],
                                      ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _bilgiSatiri(IconData ikon, String baslik, String deger) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(ikon, color: AppColors.accent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(baslik,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Text(deger,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
