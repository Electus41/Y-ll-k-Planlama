import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/ortak.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profil;
  List<Map<String, dynamic>> _birimler = [];
  bool _yukleniyor = true;
  bool _isAdmin = false;
  late final Stream<List<Map<String, dynamic>>> _profilStream;

  @override
  void initState() {
    super.initState();
    _profilStream =
        supabase.from('profiller').stream(primaryKey: ['id']).order('ad');
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
      final birimData =
          await supabase.from('birimler').select('ad, kategori').order('sira');

      if (mounted) {
        setState(() {
          _birimler = List<Map<String, dynamic>>.from(birimData);
          _profil = data ??
              {
                'ad': user.userMetadata?['ad'] ?? '',
                'soyad': user.userMetadata?['soyad'] ?? '',
                'unvan': user.userMetadata?['unvan'] ?? '',
                'telefon': user.userMetadata?['telefon'] ?? '-',
                'email': user.email ?? '',
              };
          final unvan = _profil?['unvan']?.toString() ?? '';
          _isAdmin = ustUnvanlar.contains(unvan) ||
              _profil?['yetki_seviyesi'] == 'Admin';
          _yukleniyor = false;
        });
      }
    } catch (e) {
      debugPrint('Profil alınamadı: $e');
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _oneSignalCihazKaydet() async {
    try {
      final onesignalId = OneSignal.User.pushSubscription.id;
      if (onesignalId == null || onesignalId.isEmpty) {
        if (mounted) {
          bildir(context,
              'Cihaz henüz OneSignal\'a kaydolmadı. Bildirim iznini verdiğinizden emin olun ve biraz sonra tekrar deneyin.',
              renk: Colors.orange);
        }
        return;
      }
      final user = supabase.auth.currentUser;
      if (user == null) return;
      await OneSignal.login(user.id);
      await supabase
          .from('profiller')
          .update({'onesignal_id': onesignalId}).eq('id', user.id);
      if (!mounted) return;
      setState(() => _profil?['onesignal_id'] = onesignalId);
      bildir(context, 'Bildirimler başarıyla aktifleştirildi!');
    } catch (e) {
      debugPrint('OneSignal kayıt hatası: $e');
      if (mounted) {
        bildir(context, 'Bildirim kaydı yapılamadı.', renk: Colors.red);
      }
    }
  }

  Future<void> _kullaniciSil(String id) async {
    final onay = await onayDialogu(context,
        baslik: 'Kullanıcıyı Sil',
        mesaj:
            'Bu kullanıcının profili silinecek. (Giriş hesabı Supabase > Authentication bölümünden ayrıca kaldırılmalıdır.)');
    if (!onay) return;
    try {
      final s = await supabase.from('profiller').delete().eq('id', id).select();
      if (!mounted) return;
      if (s.isEmpty) {
        bildir(context, 'Silme yetkiniz yok.', renk: Colors.orange);
      } else {
        bildir(context, 'Kullanıcı profili silindi.', renk: Colors.red);
      }
    } catch (e) {
      debugPrint('Kullanıcı silinemedi: $e');
      if (mounted) bildir(context, 'Silinemedi.', renk: Colors.red);
    }
  }

  Future<void> _baskaKullaniciDuzenleModal(
      Map<String, dynamic> kullanici) async {
    final adCtrl = TextEditingController(text: kullanici['ad'] ?? '');
    final soyadCtrl = TextEditingController(text: kullanici['soyad'] ?? '');
    final telCtrl = TextEditingController(text: kullanici['telefon'] ?? '');

    String seciliYetki = kullanici['yetki_seviyesi'] ?? 'Gönüllü';
    if (!['İl', 'İlçe', 'Gönüllü'].contains(seciliYetki)) {
      seciliYetki = 'Gönüllü';
    }
    String? seciliBirim = kullanici['unvan']?.toString();
    if (!_birimler.any((b) => b['ad'] == seciliBirim)) seciliBirim = null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setM) {
        return AlertDialog(
          backgroundColor: kutuRengi,
          title: const Text('Kullanıcı Yetkilerini Güncelle',
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
                    controller: telCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: 'Telefon',
                        labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: seciliYetki,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E292B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Yetki Seviyesi',
                      labelStyle: TextStyle(color: Colors.orangeAccent)),
                  items: ['İl', 'İlçe', 'Gönüllü']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setM(() => seciliYetki = v ?? seciliYetki),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: seciliBirim,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E292B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Bağlı Olduğu Birim / Unvan',
                      labelStyle: TextStyle(color: Colors.orangeAccent)),
                  items: _birimler
                      .map((b) => DropdownMenuItem<String>(
                          value: b['ad'].toString(),
                          child: Text(b['ad'].toString(),
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setM(() => seciliBirim = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal',
                    style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black),
              onPressed: () async {
                if (seciliBirim == null) {
                  bildir(context, 'Lütfen birim seçin!', renk: Colors.orange);
                  return;
                }
                try {
                  final sonuc = await supabase
                      .from('profiller')
                      .update({
                        'ad': adCtrl.text.trim(),
                        'soyad': soyadCtrl.text.trim(),
                        'telefon': telCtrl.text.trim(),
                        'unvan': seciliBirim,
                        'bagli_birim': seciliBirim,
                        'yetki_seviyesi': seciliYetki,
                      })
                      .eq('id', kullanici['id'])
                      .select();

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);

                  if (sonuc.isEmpty) {
                    bildir(this.context, 'Yetki hatası: işlem engellendi.',
                        renk: Colors.orange);
                    return;
                  }
                  if (kullanici['id'].toString() ==
                      supabase.auth.currentUser?.id) {
                    _profilGetir();
                  }
                  bildir(this.context, 'Kullanıcı başarıyla güncellendi!');
                } catch (e) {
                  debugPrint('Kullanıcı güncellenemedi: $e');
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  bildir(this.context, 'Güncelleme yapılamadı.',
                      renk: Colors.red);
                }
              },
              child: const Text('Güncelle',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }),
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
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final tamAd = '${_profil?['ad'] ?? ''} ${_profil?['soyad'] ?? ''}'.trim();
    final basHarf = tamAd.isNotEmpty ? tamAd[0].toUpperCase() : 'Y';
    final yetki = _profil?['yetki_seviyesi'] ?? 'Gönüllü';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profilim',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
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
                  Text(tamAd.isEmpty ? 'İsimsiz Kullanıcı' : tamAd,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          _profil?['unvan']?.toString().isNotEmpty == true
                              ? _profil!['unvan'].toString()
                              : 'Birim atanmadı',
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.orangeAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(yetki.toString(),
                            style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _bilgiSatiri(Icons.email_outlined, 'E-Posta Adresi',
                      supabase.auth.currentUser?.email ?? '-'),
                  const SizedBox(height: 12),
                  _bilgiSatiri(
                      Icons.phone_outlined,
                      'Telefon Numarası',
                      _profil?['telefon']?.toString().isNotEmpty == true
                          ? _profil!['telefon'].toString()
                          : 'Belirtilmedi'),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _oneSignalCihazKaydet,
                    child: _bilgiSatiri(
                        Icons.notifications_active_outlined,
                        'Anlık Bildirim Durumu',
                        _profil?['onesignal_id'] != null
                            ? 'Aktif (Cihaz Eşleşti) - yenilemek için dokunun'
                            : 'Bekleniyor (Aktifleştirmek İçin Dokunun)'),
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
                              borderRadius: BorderRadius.circular(12))),
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
                    const Text('Teşkilat Üyeleri ve Yetki Yönetimi',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _profilStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.accent));
                        }
                        final profiller = snapshot.data!;
                        if (profiller.isEmpty) {
                          return const Text('Kayıtlı üye bulunamadı.',
                              style: TextStyle(color: Colors.white54));
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: profiller.length,
                          itemBuilder: (context, index) {
                            final p = profiller[index];
                            final pId = p['id'].toString();
                            final ad = tamAdGetir(p);
                            final isSelf = pId == supabase.auth.currentUser?.id;
                            return Card(
                              color: AppColors.card,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                title: Text(ad.isEmpty ? 'İsimsiz' : ad,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    '${p['unvan'] ?? 'Birim yok'} • ${p['yetki_seviyesi'] ?? 'Gönüllü'}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.manage_accounts,
                                          color: Colors.blueAccent, size: 24),
                                      onPressed: () =>
                                          _baskaKullaniciDuzenleModal(p),
                                    ),
                                    if (!isSelf)
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.redAccent, size: 20),
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
          border: Border.all(color: Colors.white12)),
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
