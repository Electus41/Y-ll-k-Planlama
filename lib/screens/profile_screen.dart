import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _cikisYap(BuildContext context) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF161C1A),
            title:
                const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
            content: const Text('Oturumu kapatmak istediğinize emin misiniz?',
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
                child: const Text('Çıkış Yap',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await supabase.auth.signOut();
      if (!context.mounted) return;
      // Tüm açık sayfaları kapatıp Giriş ekranına yönlendirir
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Supabase'den aktif kullanıcının bilgilerini alır
    final user = supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF121816),
      appBar: AppBar(
        title: const Text('Yönetici Profili',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF1B4D3E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF69F0AE), width: 2),
                ),
                child: const CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF1A2220),
                  child: Icon(Icons.person, size: 50, color: Color(0xFF69F0AE)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2220),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  const Text('Aktif Oturum Bilgileri',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.email,
                          color: Colors.tealAccent, size: 20),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          user?.email ?? 'E-Posta bulunamadı',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.admin_panel_settings,
                          color: Colors.orangeAccent, size: 20),
                      SizedBox(width: 16),
                      Text('Yetki: Yönetici',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                ),
                onPressed: () => _cikisYap(context),
                icon: const Icon(Icons.logout),
                label: const Text('Oturumu Kapat',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
