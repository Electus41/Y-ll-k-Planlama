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
  bool _yukleniyor = true;
  bool _veriHatasi = false;
  List<Map<String, dynamic>> _ilceler = [];
  List<Map<String, dynamic>> _birimler = [];
  String? _ilceDeger;
  String? _talepBirimId;

  @override
  void initState() {
    super.initState();
    _verileriGetir();
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

  Future<void> _verileriGetir() async {
    if (mounted) {
      setState(() {
        _yukleniyor = true;
        _veriHatasi = false;
      });
    }
    try {
      final ilceData =
          await supabase.from('ilceler').select('id, ad').order('sira');
      final birimData = await supabase
          .from('birimler')
          .select('id, ad, kategori, ilce_id')
          .order('sira');

      // "Genel" birimini ve en üst unvanları (İl Başkanı vb.) gizliyoruz.
      // İlçe Başkanı gibi alt unvanlar serbest bırakıldı.
      final birimler = List<Map<String, dynamic>>.from(birimData).where((b) {
        final bAd = b['ad'].toString().trim();
        if (bAd.toLowerCase() == 'genel') return false;
        if (ustUnvanlar.contains(bAd)) return false;
        return true;
      }).toList();

      if (!mounted) return;
      setState(() {
        _ilceler = List<Map<String, dynamic>>.from(ilceData);
        _birimler = birimler;
        _veriHatasi = _ilceler.isEmpty;
        _yukleniyor = false;
      });
    } catch (e) {
      debugPrint('Kayıt verileri alınamadı: $e');
      if (!mounted) return;
      setState(() {
        _veriHatasi = true;
        _yukleniyor = false;
      });
      bildir(context, 'İlçe ve birim listesi yüklenemedi.', renk: Colors.red);
    }
  }

  String? get _ilceId => _ilceDeger == 'il' ? null : _ilceDeger;

  List<Map<String, dynamic>> get _birimListesi {
    if (_ilceDeger == null) return [];

    final hamListe = _birimler.where((b) {
      // 1. Sadece seçili il/ilçeye ait olanları göster
      if (b['ilce_id']?.toString() != _ilceId) return false;

      // 2. Üniversite sadece İl (Merkez) seçildiğinde görünür
      if (_ilceDeger != 'il' && b['ad'].toString().contains('Üniversite'))
        return false;

      return true;
    });

    // Çoklama (Duplicate) engelleme
    final zirhliListe = <String, Map<String, dynamic>>{};
    for (final b in hamListe) {
      final id = b['id']?.toString();
      final ad = b['ad']?.toString();
      if (id != null && ad != null) {
        if (!zirhliListe.values.any((item) => item['ad'] == ad)) {
          zirhliListe[id] = b;
        }
      }
    }
    return zirhliListe.values.toList();
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

    if (ad.isEmpty || email.isEmpty || sifre.isEmpty || _ilceDeger == null) {
      bildir(context, 'Lütfen Ad, E-posta, Şifre ve İlçe alanlarını doldurun.',
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
          'ilce_id': _ilceId,
          'talep_edilen_birim_id': _talepBirimId,
        },
      );

      if (response.user == null) {
        if (mounted) {
          bildir(context, 'Kayıt tamamlanamadı. Lütfen tekrar deneyin.',
              renk: Colors.red);
        }
        return;
      }

      if (response.session == null) {
        if (!mounted) return;
        bildir(context,
            'Kayıt alındı! E-postanıza gelen bağlantıyla hesabınızı onaylayın, sonra giriş yapın.');
        Navigator.pop(context);
        return;
      }

      await supabase.from('profiller').upsert({
        'id': response.user!.id,
        'ad': ad,
        'soyad': soyad,
        'telefon': telefon,
        'email': email,
        'ilce_id': _ilceId,
        'talep_edilen_birim_id': _talepBirimId,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('beni_hatirla', true);
      await NotificationService.kullaniciCihaziniSenkronizeEt();

      if (!mounted) return;
      bildir(context,
          'Kayıt oluşturuldu! Yöneticiniz onayladığında birim ve yetkiniz atanacak.');
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

  Widget _hataKutusu() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.orangeAccent.withValues(alpha: 0.6))),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orangeAccent, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('İlçe listesi yüklenemedi.',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          TextButton(
            onPressed: _verileriGetir,
            child: const Text('Tekrar Dene',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Widget _ilceBirimAlani() {
    if (_veriHatasi) return _hataKutusu();

    String? guvenliBirim = _talepBirimId;
    if (guvenliBirim != null &&
        !_birimListesi.any((b) => b['id'].toString() == guvenliBirim)) {
      guvenliBirim = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _ilceDeger,
          isExpanded: true,
          dropdownColor: AppColors.inputFill,
          style: const TextStyle(color: Colors.white),
          decoration: _dekor('İlçeniz / Teşkilatınız', Icons.location_city),
          items: [
            const DropdownMenuItem(
                value: 'il', child: Text('İl Teşkilatı (Merkez)')),
            ..._ilceler.map((i) => DropdownMenuItem(
                value: i['id'].toString(), child: Text(i['ad'].toString()))),
          ],
          onChanged: (v) => setState(() {
            _ilceDeger = v;
            _talepBirimId = null; // İlçe değişince birimi sıfırla
          }),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('birim_$_ilceDeger'),
          initialValue: guvenliBirim,
          isExpanded: true,
          dropdownColor: AppColors.inputFill,
          style: const TextStyle(color: Colors.white),
          decoration:
              _dekor('Görev Almak İstediğiniz Birim', Icons.account_balance),
          items: [
            const DropdownMenuItem<String>(
                value: null,
                child: Text('Henüz bilmiyorum, yönetici belirlesin')),
            ..._birimListesi.map((b) => DropdownMenuItem<String>(
                value: b['id'].toString(),
                child:
                    Text(b['ad'].toString(), overflow: TextOverflow.ellipsis))),
          ],
          onChanged: _ilceDeger == null
              ? null
              : (v) => setState(() => _talepBirimId = v),
        ),
      ],
    );
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
          child: _yukleniyor
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
                            'İlçenizi seçin. Birim ve yetkiniz yöneticiniz onayladıktan sonra atanır.',
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
                        _ilceBirimAlani(),
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
