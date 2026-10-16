import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_shell.dart';
import 'login_page.dart';
import 'services/auth_service.dart';

void main() => runApp(const LigtasApp());

class LigtasApp extends StatefulWidget {
  const LigtasApp({super.key, this.auth});

  /// Injected by tests. The real one reads shared_preferences, which is a
  /// platform channel and does not exist under flutter_test.
  final AuthService? auth;

  @override
  State<LigtasApp> createState() => _LigtasAppState();
}

class _LigtasAppState extends State<LigtasApp> {
  late final AuthService _auth = widget.auth ?? AuthService();

  /// True while we check for a previous session on startup.
  bool _checking = true;

  /// True once we know whether a usable session exists. Drives which page is
  /// built, so sign-out and restore are the same switch.
  bool _signedIn = false;

  /// The rescuee restoreSession() already fetched. The account tab shows it
  /// instead of inventing a profile screen that would need a second call.
  AuthUser? _user;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Open straight into the app if the stored token is still good, so a
  /// rescuee mid-emergency is never bounced to the login screen by a restart.
  Future<void> _restore() async {
    final user = await _auth.restoreSession();

    if (!mounted) return;
    setState(() {
      _signedIn = user != null;
      _user = user;
      _checking = false;
    });
  }

  @override
  void dispose() {
    // Only close what we created. A test-injected fake may not be closeable.
    if (widget.auth == null) _auth.close();
    super.dispose();
  }

  Future<void> _signOut() async {
    await _auth.logout();

    if (!mounted) return;
    setState(() => _signedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LigtasAlert - Rescuee App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
      ),
      // ponytail: one boolean swaps the pages instead of pushing routes.
      // Pushing HomePage on top of login left it stuck there after sign-out,
      // because rebuilding `home:` cannot dismiss a route already on the
      // Navigator stack. A switch has no such asymmetry.
      home: _checking
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _signedIn
              ? BottomShell(
                  auth: _auth,
                  user: _user,
                  onSignOut: _signOut,
                )
              : LoginPage(
                  auth: _auth,
                  onLoggedIn: () => setState(() => _signedIn = true),
                ),
    );
  }
}