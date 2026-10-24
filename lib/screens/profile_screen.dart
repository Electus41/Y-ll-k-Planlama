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
          _yukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _profil = {
            'ad': user.userMetadata?['ad'] ?? '',
            'soyad': user.userMetadata?['soyad'] ?? '',
            'unvan': user.userMetadata?['unvan'] ?? 'Yönetici',
            'telefon': user.userMetadata?['telefon'] ?? '-',
            'email': user.email ?? '',
          };
          _yukleniyor = false;
        });
      }
    }
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
                  Text(
                    tamAd.isEmpty ? 'İsimsiz Yönetici' : tamAd,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
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
                  _bilgiSatiri(
                    Icons.notifications_active_outlined,
                    'Anlık Bildirim Durumu',
                    _profil?['onesignal_id'] != null
                        ? 'Aktif (Cihaz Eşleşti)'
                        : 'Bekleniyor (OneSignal Anahtarı Girilmeli)',
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
