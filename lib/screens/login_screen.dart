import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/notification_service.dart';
import '../core/ortak.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _sifreController.dispose();
    super.dispose();
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

  InputDecoration _dekor(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon,
            color: Colors.tealAccent.withValues(alpha: 0.7), size: 20),
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

  String _hataMesaji(Object e) {
    final s = (e is AuthException ? e.message : e.toString()).toLowerCase();
    if (s.contains('invalid login credentials') ||
        s.contains('invalid_credentials')) {
      return 'E-posta adresi veya şifre hatalı.';
    }
    if (s.contains('email not confirmed')) {
      return 'E-posta adresiniz henüz onaylanmamış.';
    }
    if (s.contains('rate limit') || s.contains('429')) {
      return 'Çok fazla deneme yapıldı. Lütfen biraz bekleyin.';
    }
    if (s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('network')) {
      return 'İnternet bağlantısı kurulamadı.';
    }
    return 'Giriş yapılamadı. Lütfen tekrar deneyin.';
  }

  Future<void> _girisYap() async {
    final email = _emailController.text.trim();
    final sifre = _sifreController.text.trim();
    if (email.isEmpty || sifre.isEmpty) {
      bildir(context, 'Lütfen e-posta ve şifrenizi girin.',
          renk: Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authResponse =
          await supabase.auth.signInWithPassword(email: email, password: sifre);

      if (authResponse.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('beni_hatirla', _beniHatirla);
        if (_beniHatirla) {
          await prefs.setString('kayitli_email', email);
        } else {
          await prefs.remove('kayitli_email');
        }

        await NotificationService.kullaniciCihaziniSenkronizeEt();

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ActivitiesScreen()),
        );
      }
    } catch (e) {
      debugPrint('Giriş hatası: $e');
      if (!mounted) return;
      bildir(context, _hataMesaji(e), renk: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sifremiUnuttumModalAc() {
    final resetCtrl = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kutuRengi,
        title: const Text('Şifremi Unuttum',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Şifre sıfırlama talimatlarını almak için e-posta adresinizi girin.',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: resetCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _dekor('E-posta Adresi', Icons.email_outlined),
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
              if (resetCtrl.text.trim().isEmpty) return;
              try {
                await supabase.auth
                    .resetPasswordForEmail(resetCtrl.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                bildir(context,
                    'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.');
              } catch (err) {
                debugPrint('Şifre sıfırlama hatası: $err');
                if (!ctx.mounted) return;
                bildir(context,
                    'Sıfırlama bağlantısı gönderilemedi. E-postayı kontrol edin.',
                    renk: Colors.red);
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
        padding: const EdgeInsets.all(20),
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
                    decoration: _dekor('E-posta Adresi', Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _sifreController,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _girisYap(),
                    obscureText: true,
                    decoration: _dekor('Şifre', Icons.lock_outline),
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
                            onChanged: (v) =>
                                setState(() => _beniHatirla = v ?? false),
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
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen())),
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
