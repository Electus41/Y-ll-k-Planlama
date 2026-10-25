import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/notification_service.dart';
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
  final _sifreController = TextEditingController();

  bool _isLoading = false;
  bool _birimlerYukleniyor = true;
  List<String> _birimler = [];
  String? _seciliBirim;

  @override
  void initState() {
    super.initState();
    _birimleriGetir();
  }

  Future<void> _birimleriGetir() async {
    try {
      final data = await supabase
          .from('teskilat_birimleri')
          .select('birim_adi')
          .order('birim_adi');

      if (mounted) {
        setState(() {
          _birimler =
              List<String>.from(data.map((b) => b['birim_adi'].toString()));
          _birimlerYukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _birimlerYukleniyor = false);
    }
  }

  InputDecoration _koyuInputDekorasyonu(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  Future<void> _kayitOl() async {
    if (_adController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _sifreController.text.trim().isEmpty ||
        _seciliBirim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Lütfen Ad, E-posta, Şifre ve Birim alanlarını doldurun.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final ad = _adController.text.trim();
      final soyad = _soyadController.text.trim();
      final telefon = _telefonController.text.trim();

      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _sifreController.text.trim(),
        data: {
          'ad': ad,
          'soyad': soyad,
          'telefon': telefon,
        },
      );

      if (response.user != null) {
        // Yeni RBAC Mimarisindeki Güvenli Varsayılan Değerlerle Profil Oluşturma
        await supabase.from('profiller').upsert({
          'id': response.user!.id,
          'ad': ad,
          'soyad': soyad,
          'telefon': telefon,
          'email': _emailController.text.trim(),
          'unvan': _seciliBirim,
          'bagli_birim': _seciliBirim,
          'yetki_seviyesi': 'Gönüllü', // GÜVENLİK: Her yeni üye gönüllü başlar
          'bagli_ilce': 'Tümü',
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('beni_hatirla', true);
        await NotificationService.kullaniciCihaziniSenkronizeEt();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Kayıt başarıyla oluşturuldu!'),
              backgroundColor: Colors.green),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ActivitiesScreen()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Kayıt başarısız: ${e.message}'),
            backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Sistem Hatası: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yeni Üye Kaydı',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: _birimlerYukleniyor
              ? const CircularProgressIndicator(color: AppColors.accent)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Ailemize Katılın',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Lütfen görev almak istediğiniz birimi ve bilgilerinizi eksiksiz girin.',
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
                              label: 'E-posta Adresi',
                              icon: Icons.email_outlined),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _telefonController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: _koyuInputDekorasyonu(
                              label: 'Telefon Numarası',
                              icon: Icons.phone_outlined),
                        ),
                        const SizedBox(height: 16),

                        // Dinamik Birim Dropdown (Elle unvan girme yerine)
                        DropdownButtonFormField<String>(
                          value: _seciliBirim,
                          dropdownColor: AppColors.inputFill,
                          style: const TextStyle(color: Colors.white),
                          decoration: _koyuInputDekorasyonu(
                              label: 'Görev Almak İstediğiniz Birim',
                              icon: Icons.account_balance),
                          items: _birimler
                              .map((b) =>
                                  DropdownMenuItem(value: b, child: Text(b)))
                              .toList(),
                          onChanged: (v) => setState(() => _seciliBirim = v),
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
                              backgroundColor: AppColors.accent,
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
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
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
