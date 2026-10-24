import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'activities_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _adController = TextEditingController();
  final _soyadController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonController = TextEditingController();
  final _unvanController = TextEditingController();
  final _sifreController = TextEditingController();
  bool _isLoading = false;

  InputDecoration _koyuInputDekorasyonu(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF69F0AE), size: 20),
      filled: true,
      fillColor: const Color(0xFF1F2624),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white12)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF69F0AE), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  Future<void> _kayitOl() async {
    if (_emailController.text.trim().isEmpty ||
        _sifreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lütfen e-posta ve şifre alanlarını doldurun.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _sifreController.text.trim(),
        data: {
          'ad': _adController.text.trim(),
          'soyad': _soyadController.text.trim(),
          'telefon': _telefonController.text.trim(),
          'unvan': _unvanController.text.trim(),
        },
      );

      if (response.user != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Kayıt başarıyla oluşturuldu!'),
              backgroundColor: Colors.green),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ActivitiesScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Kayıt başarısız: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121816),
      appBar: AppBar(
        title: const Text('Yeni Yönetici Kaydı',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B4D3E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Teşkilat Yönetim Paneli',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Yeni yönetici hesabı oluşturmak için bilgileri doldurun.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _adController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _koyuInputDekorasyonu(
                              label: 'Ad', icon: Icons.person_outline),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _soyadController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _koyuInputDekorasyonu(
                              label: 'Soyad', icon: Icons.person_outline),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _koyuInputDekorasyonu(
                        label: 'E-posta Adresi', icon: Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _telefonController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: _koyuInputDekorasyonu(
                        label: 'Telefon Numarası', icon: Icons.phone_outlined),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _unvanController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _koyuInputDekorasyonu(
                        label: 'Kurumsal Unvan (Örn: İl Başkan Yardımcısı)',
                        icon: Icons.badge_outlined),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _sifreController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _koyuInputDekorasyonu(
                        label: 'Şifre', icon: Icons.lock_outline),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF69F0AE),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      onPressed: _isLoading ? null : _kayitOl,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2))
                          : const Text('Kayıt Ol',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
