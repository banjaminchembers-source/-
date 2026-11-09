import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CookieDimonApp());
}

class CookieDimonApp extends StatelessWidget {
  const CookieDimonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cookie Dimon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC9823E),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF17110D),
        useMaterial3: true,
      ),
      home: const CookieSetupPage(),
    );
  }
}

class CookieSetupPage extends StatelessWidget {
  const CookieSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🍪', style: TextStyle(fontSize: 92)),
                const SizedBox(height: 18),
                const Text(
                  'Печенька уже здесь!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Разреши показ поверх других приложений. После этого маленькая печенька появится на экране. Её можно перетаскивать, а при касании она засмеётся голосом Димона.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.5, color: Colors.white70),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Это окно можно закрыть. Печенька останется поверх остальных приложений.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
