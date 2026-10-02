import 'package:flutter/material.dart';
import 'constants.dart';
import 'home_page.dart';
import 'login_page.dart';

void main() => runApp(const LigtasApp());

class LigtasApp extends StatelessWidget {
  const LigtasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LigtasAlert - Rescuee App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
      ),
      // ponytail: Builder so onLoggedIn's context sits *below* the Navigator
      // that MaterialApp installs. LigtasApp's own context is above it, and
      // Navigator.of() there throws - which makes the login button look dead.
      home: Builder(
        builder: (context) => LoginPage(
          onLoggedIn: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => HomePage(
                  onSignOut: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
