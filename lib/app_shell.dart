import 'package:flutter/material.dart';
import 'constants.dart';
import 'account_page.dart';
import 'home_page.dart';
import 'services/alert_api.dart';
import 'services/auth_service.dart';

/// Persistent bottom navigation for the authenticated app.
///
/// ponytail: the old menu had one action (sign out) behind an icon button, so
/// the app's only two real destinations were the alert screen and the account.
/// A two-item [BottomNavigationBar] replaces the button and the sheet with
/// something a rescuee can find by muscle memory in a hurry.
///
/// [IndexedStack] keeps each tab's state alive when switching: the alert form
/// keeps its selected type and room, and an in-flight send is not restarted.
/// The status page is still pushed on top of the shell as its own route, so
/// its lifecycle, timers and cleanup are unchanged.
class BottomShell extends StatefulWidget {
  const BottomShell({
    super.key,
    required this.auth,
    required this.onSignOut,
    this.api,
    this.user,
  });

  final AuthService auth;
  final VoidCallback onSignOut;
  final AlertApi? api;
  final AuthUser? user;

  @override
  State<BottomShell> createState() => _BottomShellState();
}

class _BottomShellState extends State<BottomShell> {
  // ponytail: a ValueNotifier, not a plain int + setState, so the bar can be
  // driven from a test without mounting a full stateful widget tree.
  final _index = ValueNotifier<int>(0);

  @override
  void dispose() {
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: ValueListenableBuilder<int>(
        valueListenable: _index,
        builder: (context, index, _) {
          return IndexedStack(
            index: index,
            children: [
              HomePage(
                auth: widget.auth,
                api: widget.api,
                onSignOut: widget.onSignOut,
              ),
              AccountPage(user: widget.user, onSignOut: widget.onSignOut),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomShellBar(
        currentIndex: _index.value,
        onSelect: (i) => _index.value = i,
      ),
    );
  }
}

/// The bar itself, separated so tests can drive it without the shell.
class BottomShellBar extends StatelessWidget {
  const BottomShellBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onSelect,
      backgroundColor: kSurface,
      elevation: 8,
      selectedItemColor: kPrimary,
      unselectedItemColor: kTextSecondary,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      showUnselectedLabels: true,
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.warning_amber_rounded, size: 26),
          label: 'Alert',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person_rounded, size: 26),
          label: 'Account',
        ),
      ],
    );
  }
}