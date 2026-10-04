import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants.dart';
import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onLoggedIn, this.auth, this.openUrl});

  final VoidCallback? onLoggedIn;

  /// Injected by tests; defaults to the real backend client.
  final AuthService? auth;

  /// Opens the Microsoft consent page in a real browser. Injected by tests,
  /// which must not launch anything.
  final Future<bool> Function(String url)? openUrl;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _busy = false;

  AuthService? _ownedAuth;

  AuthService get _auth => widget.auth ?? (_ownedAuth ??= AuthService());

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _ownedAuth?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBrandHeader(),

                    const SizedBox(height: 28),

                    _buildLoginCard(),

                    const SizedBox(height: 22),

                    _buildFooter(),

                    const SizedBox(height: 18),

                    const Text(
                      'Emergency? Use the alert screen without signing in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                kPrimary,
                kPrimary.withValues(alpha: 0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_rounded,
            size: 42,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 18),

        const Text(
          'LigtasAlert',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: kTextPrimary,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Sign in to keep your safety profile and room on file.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: kTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome back',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
            ),
          ),

          const SizedBox(height: 18),

          _buildNameField(),

          const SizedBox(height: 14),

          _buildEmailField(),

          const SizedBox(height: 14),

          _buildPasswordField(),

          const SizedBox(height: 8),

          _buildForgotPassword(),

          const SizedBox(height: 20),

          _buildSignInButton(),

          const SizedBox(height: 16),

          _buildMicrosoftButton(),

          const SizedBox(height: 16),

          _buildDivider(),

          const SizedBox(height: 16),

          _buildSignUpButton(),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _name,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() {}),
      decoration: _inputDecoration(
        icon: Icons.person_outline_rounded,
        label: 'Full name',
        hint: 'Juan Dela Cruz',
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() {}),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return 'Enter your email';
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
          return 'Enter a valid email';
        }
        return null;
      },
      decoration: _inputDecoration(
        icon: Icons.mail_outline_rounded,
        label: 'Email',
        hint: 'you@campus.edu',
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _password,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(() {}),
      onFieldSubmitted: (_) => _submit(),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Enter your password';
        if (value.length < 6) return 'Password must be 6+ characters';
        return null;
      },
      decoration: _inputDecoration(
        icon: Icons.lock_outline_rounded,
        label: 'Password',
        hint: 'Enter your password',
        suffix: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            size: 20,
            color: kTextSecondary,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Row(
      children: [
        TextButton(
          onPressed: _showResetHelp,
          style: TextButton.styleFrom(
            foregroundColor: kPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Forgot password?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton() {
    final enabled =
        !_busy && _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

    return SizedBox(
      height: 58,
      child: FilledButton(
        onPressed: enabled ? _submit : null,
        style: FilledButton.styleFrom(
          backgroundColor: kPrimary,
          disabledBackgroundColor: kBorder,
          foregroundColor: Colors.white,
          disabledForegroundColor: kTextSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Log In',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMicrosoftButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _microsoftSignIn,
        style: OutlinedButton.styleFrom(
          foregroundColor: kTextPrimary,
          side: const BorderSide(color: kBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        // The four-square Microsoft mark, inlined so it needs no asset or
        // network fetch. Same colours as the web sign-in page.
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: _MicrosoftLogo(),
        ),
        label: const Text(
          'Continue with Microsoft',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: kBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kTextSecondary.withValues(alpha: 0.9),
            ),
          ),
        ),
        const Expanded(child: Divider(color: kBorder)),
      ],
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _register,
        style: OutlinedButton.styleFrom(
          foregroundColor: kTextPrimary,
          side: const BorderSide(color: kBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(
          Icons.person_add_alt_rounded,
          size: 20,
        ),
        label: const Text(
          'Create an account',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.verified_user_outlined,
          size: 16,
          color: kTextSecondary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Your data stays on campus',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kTextSecondary.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }

  void _showResetHelp() {
    // ponytail: no backend, so no real reset flow. Telling the user who to ask
    // is the honest version of this button - a fake "email sent" dialog would
    // be a lie the user acts on. Wire a real reset endpoint here when there is one.
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Reset your password'),
        content: const Text(
          'Contact your facility security office, or the LigtasAlert admin, '
          'to reset your password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);

    try {
      await _auth.login(_email.text.trim(), _password.text);
      if (!mounted) return;
      widget.onLoggedIn?.call();
    } on AuthException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _name.text.trim();
    if (name.isEmpty) {
      _showError('Enter your name');
      return;
    }

    setState(() => _busy = true);

    try {
      await _auth.register(name, _email.text.trim(), _password.text);
      if (!mounted) return;
      widget.onLoggedIn?.call();
    } on AuthException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens Microsoft's sign-in page in the system browser, then polls the
  /// backend until the callback has handed back a token. The consent screen is
  /// always a real browser page, so the user can see which account they pick.
  Future<void> _microsoftSignIn() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final start = await _auth.microsoftStart();

      final open = widget.openUrl ?? _openInBrowser;
      if (!await open(start.url)) {
        throw AuthException('Could not open the Microsoft sign-in page.');
      }

      final result = await _auth.microsoftFinish(start.state);
      if (!mounted) return;
      _email.text = result.user.email;
      widget.onLoggedIn?.call();
    } on AuthException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// External application mode keeps the consent page out of the app, so the
  /// rescuee can authenticate with Microsoft without us handling credentials.
  Future<bool> _openInBrowser(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kTextPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required IconData icon,
    required String label,
    required String hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: kTextSecondary,
      ),
      suffixIcon: suffix,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: kBg,
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      border: outlineBorder(14),
      enabledBorder: outlineBorder(14),
      focusedBorder: outlineBorder(14, color: kPrimary, width: 2),
      errorBorder: outlineBorder(14, color: kPrimary, width: 1.5),
      focusedErrorBorder: outlineBorder(14, color: kPrimary, width: 2),
    );
  }
}
/// The four-colour Microsoft mark, drawn inline so it needs no asset file.
class _MicrosoftLogo extends StatelessWidget {
  const _MicrosoftLogo();

  @override
  Widget build(BuildContext context) {
    Widget square(Color color) => Container(width: 8, height: 8, color: color);

    // Two rows of two squares, filling the caller's 18x18 box.
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            square(const Color(0xFFF25022)),
            const SizedBox(width: 2),
            square(const Color(0xFF7FBA00)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            square(const Color(0xFF00A4EF)),
            const SizedBox(width: 2),
            square(const Color(0xFFBFB900)),
          ],
        ),
      ],
    );
  }
}
