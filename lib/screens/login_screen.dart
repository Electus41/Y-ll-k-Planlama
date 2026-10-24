import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/notification_service.dart';
import 'activities_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _sifreController = TextEditingController();
  bool _beniHatirla = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _kayitliBilgileriYukle();
  }

  Future<void> _kayitliBilgileriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final kayitliEmail = prefs.getString('kayitli_email') ?? '';
    final hatirla = prefs.getBool('beni_hatirla') ?? true;
    if (mounted) {
      setState(() {
        _beniHatirla = hatirla;
        if (hatirla && kayitliEmail.isNotEmpty) {
          _emailController.text = kayitliEmail;
        }
      });
    }
  }

  InputDecoration _koyuInputDekorasyonu(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon:
          Icon(icon, color: Colors.tealAccent.withValues(alpha: 0.7), size: 20),
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white30),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
    );
  }

  Future<void> _girisYap() async {
    if (_emailController.text.trim().isEmpty ||
        _sifreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lütfen e-posta ve şifrenizi girin.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authResponse = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _sifreController.text.trim(),
      );

      if (authResponse.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('beni_hatirla', _beniHatirla);
        if (_beniHatirla) {
          await prefs.setString('kayitli_email', _emailController.text.trim());
        } else {
          await prefs.remove('kayitli_email');
        }

        await NotificationService.kullaniciCihaziniSenkronizeEt();

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ActivitiesScreen()),
        );
      }
    } catch (e) {
      String kullaniciMesaji = 'E-posta adresi veya şifre hatalı.';
      final hataStr = e.toString().toLowerCase();

      if (hataStr.contains('over_email_send_rate_limit') ||
          hataStr.contains('429')) {
        kullaniciMesaji = 'Çok fazla deneme yapıldı. Lütfen biraz bekleyin.';
      } else if (hataStr.contains('email not confirmed')) {
        kullaniciMesaji = 'E-posta adresiniz henüz onaylanmamış.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(kullaniciMesaji),
            backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sifremiUnuttumModalAc() {
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161C1A),
        title: const Text('Şifremi Unuttum',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Şifre sıfırlama talimatlarını almak için e-posta adresinizi girin.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: resetEmailController,
              style: const TextStyle(color: Colors.white),
              decoration: _koyuInputDekorasyonu(
                  label: 'E-posta Adresi', icon: Icons.email_outlined),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              if (resetEmailController.text.trim().isEmpty) return;
              try {
                await supabase.auth
                    .resetPasswordForEmail(resetEmailController.text.trim());
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (err) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Sıfırlama bağlantısı gönderilemedi. E-postayı kontrol edin.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Gönder',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kocaeli Genç İHH - Giriş',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.secondary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          blurRadius: 35,
                          spreadRadius: 8,
                        )
                      ],
                    ),
                    child: Image.asset('assets/images/logo.png', height: 95),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.next,
                    decoration: _koyuInputDekorasyonu(
                        label: 'E-posta Adresi', icon: Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _sifreController,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _girisYap(),
                    obscureText: true,
                    decoration: _koyuInputDekorasyonu(
                        label: 'Şifre', icon: Icons.lock_outline),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _beniHatirla,
                            activeColor: AppColors.accent,
                            checkColor: Colors.black,
                            side: const BorderSide(color: Colors.white54),
                            onChanged: (val) =>
                                setState(() => _beniHatirla = val ?? false),
                          ),
                          const Text('Beni hatırla',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                      TextButton(
                        onPressed: _sifremiUnuttumModalAc,
                        child: const Text('Şifremi unuttum',
                            style: TextStyle(color: Colors.tealAccent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const CircularProgressIndicator(color: AppColors.accent)
                      : SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _girisYap,
                            child: const Text('Giriş Yap',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: const Text('Hesabınız yok mu? Kayıt Olun',
                        style: TextStyle(color: Colors.tealAccent)),
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
