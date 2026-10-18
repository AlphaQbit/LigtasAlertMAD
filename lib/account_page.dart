import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'constants.dart';
import 'services/auth_service.dart';

/// The rescuee's account screen.
///
/// ponytail: this is not a new feature. AuthService already fetches the user's
/// name and email on login and on session restore - it just never showed them
/// anywhere, because the only navigation was a one-item menu that opened sign
/// out. Surfacing the profile here reuses data the app already has rather than
/// inventing a settings screen with toggles nobody asked for.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, this.user, this.onSignOut});

  /// Null when the page is built before restoreSession resolves; the shell
  /// always passes the real user for an authenticated session.
  final AuthUser? user;

  final VoidCallback? onSignOut;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Account',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),

            _buildProfileCard(),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton.icon(
                onPressed: widget.onSignOut,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  foregroundColor: kPrimary,
                  side: const BorderSide(color: kPrimary, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(LucideIcons.log_out, size: 20),
                label: const Text(
                  'Sign out',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.user,
              size: 36,
              color: kPrimary,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            widget.user?.name.isEmpty ?? true
                ? 'Your account'
                : widget.user!.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            widget.user?.email.isEmpty ?? true
                ? 'Signed in on this device'
                : widget.user!.email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: kTextSecondary,
            ),
          ),

          const SizedBox(height: 18),

          const Divider(height: 1, color: kBorder),

          const SizedBox(height: 16),

          _buildProfileRow(
            LucideIcons.shield_check,
            'Safety profile',
            'Kept on file with your facility',
          ),
          const SizedBox(height: 14),
          _buildProfileRow(
            LucideIcons.building,
            'Default room',
            'Set when you send an alert',
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: kTextSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kTextSecondary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}