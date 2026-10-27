import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'core/notification_service.dart';
import 'screens/activities_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // anonKey uyarısını çözmek için publishableKey kullanıldı
  await Supabase.initialize(
    url: 'https://ricvcziubadmdkogwfxd.supabase.co',
    publishableKey: 'sb_publishable_OxFaHkmvQr0ZIw1i0utZvA_HEroyOj-',
  );

  await NotificationService.baslat();

  final prefs = await SharedPreferences.getInstance();
  final beniHatirla = prefs.getBool('beni_hatirla') ?? true;
  final mevcutOturum = Supabase.instance.client.auth.currentSession;

  bool dogrudanGiris = false;
  if (mevcutOturum != null) {
    if (beniHatirla) {
      dogrudanGiris = true;
      await NotificationService.kullaniciCihaziniSenkronizeEt();
    } else {
      await Supabase.instance.client.auth.signOut();
    }
  }

  runApp(KocaeliGenclikApp(dogrudanGiris: dogrudanGiris));
}

class KocaeliGenclikApp extends StatelessWidget {
  final bool dogrudanGiris;
  const KocaeliGenclikApp({super.key, required this.dogrudanGiris});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kocaeli Genç İHH Yıllık Plan',
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: dogrudanGiris ? const ActivitiesScreen() : const LoginScreen(),
    );
  }
}
