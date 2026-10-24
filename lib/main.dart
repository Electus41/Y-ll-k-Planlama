import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/activities_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ricvcziubadmdkogwfxd.supabase.co',
    anonKey: 'sb_publishable_OxFaHkmvQr0ZIw1i0utZvA_HEroyOj-',
  );

  runApp(const KocaeliGenclikApp());
}

class KocaeliGenclikApp extends StatelessWidget {
  const KocaeliGenclikApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Supabase üzerinde aktif bir oturum olup olmadığını kontrol eder
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kocaeli Genç İHH Yıllık Plan',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF121816),
      ),
      // Oturum varsa doğrudan ana ekran, yoksa Login ekranı açılır
      home: session != null ? const ActivitiesScreen() : const LoginScreen(),
    );
  }
}
