import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/notification_service.dart';
import '../core/ortak.dart';
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

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _emailController.dispose();
    _telefonController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  Future<void> _birimleriGetir() async {
    try {
      // "Yönetim" kategorisindeki üst unvanlar kayıtta seçilemez.
      final data = await supabase
          .from('birimler')
          .select('ad, kategori')
          .neq('kategori', 'Yönetim')
          .order('sira');
      if (mounted) {
        setState(() {
          _birimler = data.map<String>((b) => b['ad'].toString()).toList();
          _birimlerYukleniyor = false;
        });
      }
    } catch (e) {
      debugPrint('Birimler alınamadı: $e');
      if (mounted) setState(() => _birimlerYukleniyor = false);
    }
  }

  InputDecoration _dekor(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      );

  Future<void> _kayitOl() async {
    final ad = _adController.text.trim();
    final soyad = _soyadController.text.trim();
    final telefon = _telefonController.text.trim();
    final email = _emailController.text.trim();
    final sifre = _sifreController.text.trim();

    if (ad.isEmpty || email.isEmpty || sifre.isEmpty || _seciliBirim == null) {
      bildir(context, 'Lütfen Ad, E-posta, Şifre ve Birim alanlarını doldurun.',
          renk: Colors.orange);
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      bildir(context, 'Lütfen geçerli bir e-posta adresi girin.',
          renk: Colors.orange);
      return;
    }
    if (sifre.length < 6) {
      bildir(context, 'Şifre en az 6 karakter olmalı.', renk: Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: sifre,
        data: {
          'ad': ad,
          'soyad': soyad,
          'telefon': telefon,
          'unvan': _seciliBirim,
          'bagli_birim': _seciliBirim,
        },
      );

      if (response.user == null) {
        if (mounted) {
          bildir(context, 'Kayıt tamamlanamadı. Lütfen tekrar deneyin.',
              renk: Colors.red);
        }
        return;
      }

      // E-posta onayı açıksa oturum henüz yoktur.
      if (response.session == null) {
        if (!mounted) return;
        bildir(context,
            'Kayıt alındı! Lütfen e-postanıza gelen bağlantıyla hesabınızı onaylayın, sonra giriş yapın.');
        Navigator.pop(context);
        return;
      }

      // Yetki ve üst unvanlar sunucudaki trigger ile korunur: yeni üye her zaman "Gönüllü" başlar.
      await supabase.from('profiller').upsert({
        'id': response.user!.id,
        'ad': ad,
        'soyad': soyad,
        'telefon': telefon,
        'email': email,
        'unvan': _seciliBirim,
        'bagli_birim': _seciliBirim,
        'yetki_seviyesi': 'Gönüllü',
        'bagli_ilce': 'Tümü',
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('beni_hatirla', true);
      await NotificationService.kullaniciCihaziniSenkronizeEt();

      if (!mounted) return;
      bildir(context, 'Kayıt başarıyla oluşturuldu!');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ActivitiesScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final m = e.message.toLowerCase();
      final metin = m.contains('already registered')
          ? 'Bu e-posta adresiyle zaten bir hesap var.'
          : m.contains('rate limit')
              ? 'Çok fazla deneme yapıldı. Lütfen biraz bekleyin.'
              : 'Kayıt başarısız: ${e.message}';
      bildir(context, metin, renk: Colors.red);
    } catch (e) {
      debugPrint('Kayıt hatası: $e');
      if (mounted) {
        bildir(context,
            'Kayıt sırasında bir sorun oluştu. Bağlantınızı kontrol edin.',
            renk: Colors.red);
      }
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
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Ailemize Katılın',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        const Text(
                            'Lütfen görev almak istediğiniz birimi ve bilgilerinizi eksiksiz girin.',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 13),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _adController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _dekor('Ad', Icons.person_outline),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _soyadController,
                                style: const TextStyle(color: Colors.white),
                                decoration:
                                    _dekor('Soyad', Icons.person_outline),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration:
                              _dekor('E-posta Adresi', Icons.email_outlined),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _telefonController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration:
                              _dekor('Telefon Numarası', Icons.phone_outlined),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _seciliBirim,
                          isExpanded: true,
                          dropdownColor: AppColors.inputFill,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dekor('Görev Almak İstediğiniz Birim',
                              Icons.account_balance),
                          items: _birimler
                              .map((b) => DropdownMenuItem(
                                  value: b,
                                  child:
                                      Text(b, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) => setState(() => _seciliBirim = v),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _sifreController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dekor(
                              'Şifre (en az 6 karakter)', Icons.lock_outline),
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
