import 'package:flutter/material.dart';
import 'constants.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onLoggedIn});

  final VoidCallback? onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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

          _buildEmailField(),

          const SizedBox(height: 14),

          _buildPasswordField(),

          const SizedBox(height: 8),

          _buildRememberRow(),

          const SizedBox(height: 20),

          _buildSignInButton(),

          const SizedBox(height: 16),

          _buildDivider(),

          const SizedBox(height: 16),

          _buildSignUpButton(),
        ],
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

  Widget _buildRememberRow() {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _rememberMe,
            onChanged: (value) {
              setState(() {
                _rememberMe = value ?? false;
              });
            },
            activeColor: kPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),

        const SizedBox(width: 10),

        const Expanded(
          child: Text(
            'Remember me',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
        ),

        const SizedBox(width: 8),

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
    final enabled = _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

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
        onPressed: () {},
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

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // ponytail: no backend yet, so login is a stub that just hands off to the
    // caller's onLoggedIn. Wire real auth here (or a routing package) later.
    widget.onLoggedIn?.call();
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
