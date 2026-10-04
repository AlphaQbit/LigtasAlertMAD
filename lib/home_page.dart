import 'dart:async';

import 'package:flutter/material.dart';
import 'constants.dart';
import 'alert_status_page.dart';
import 'services/alert_api.dart';
import 'services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onSignOut, this.api, this.auth});

  final VoidCallback? onSignOut;

  /// Injected by tests; defaults to the real backend client.
  final AlertApi? api;

  /// Supplies the bearer token the status page needs to read alert updates.
  /// Sending an alert is unauthenticated, but reading its status is not.
  final AuthService? auth;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _room = TextEditingController(text: 'Room 214');
  String? _selectedType;
  String _facility = facilities.first.id;
  bool _sending = false;

  // Built on first use and kept, because AlertApi owns an HttpClient that has
  // to be closed in dispose. Reading it in dispose must not create one.
  AlertApi? _ownedApi;

  AlertApi get _api =>
      widget.api ?? (_ownedApi ??= AlertApi(token: widget.auth?.token));

  @override
  void dispose() {
    _room.dispose();
    _ownedApi?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 4,
        leading: IconButton(
          icon: const Icon(
            Icons.menu_rounded,
            size: 30,
          ),
          tooltip: 'Menu',
          onPressed: _openMenu,
        ),
        title: const Text(
          'LigtasAlert',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLocationPanel(),

              const SizedBox(height: 30),

              const Text(
                'Emergency Alert',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Select the type of emergency',
                style: TextStyle(
                  fontSize: 14,
                  color: kTextSecondary,
                ),
              ),

              const SizedBox(height: 16),

              _buildAlertGrid(),

              const SizedBox(height: 28),

              _buildSendButton(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendAlert() async {
    if (_sending) return;

    setState(() => _sending = true);

    final facility = facilities.firstWhere(
      (item) => item.id == _facility,
      orElse: () => facilities.first,
    );

    try {
      final alert = await _api.sendAlert(
        facility: facility.label,
        type: _selectedType!,
        location: _room.text.trim().isEmpty
            ? facility.label
            : _room.text.trim(),
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AlertStatusPage(alert: alert, api: _api)),
      );

      // Back from the status screen: reset so a new alert can be sent.
      if (mounted) setState(() => _sending = false);
    } on AlertApiException catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showError(error.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kTextPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: kPrimary),
              title: const Text(
                'Sign out',
                style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(sheet);
                widget.onSignOut?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPanel() {
    final facility = facilities.firstWhere(
      (item) => item.id == _facility,
      orElse: () => facilities.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: kBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR LOCATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: kTextSecondary,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: kPrimary,
                  size: 27,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facility.label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _room.text.isEmpty
                          ? 'No room specified'
                          : _room.text,
                      style: const TextStyle(
                        fontSize: 14,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kOkBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: kOkDot,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Ready',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: kOkText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildLocationDropdown(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRoomField(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _facility,
      isExpanded: true,
      decoration: _inputDecoration(
        icon: Icons.business_rounded,
        hint: 'Facility',
      ),
      items: [
        for (final facility in facilities)
          DropdownMenuItem(
            value: facility.id,
            child: Text(
              facility.label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        setState(() {
          _facility = value ?? _facility;
        });
      },
    );
  }

  Widget _buildRoomField() {
    return TextField(
      controller: _room,
      onChanged: (_) {
        setState(() {});
      },
      decoration: _inputDecoration(
        icon: Icons.room_rounded,
        hint: 'Room / Location',
      ),
    );
  }

  InputDecoration _inputDecoration({
    required IconData icon,
    required String hint,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        size: 19,
        color: kTextSecondary,
      ),
      filled: true,
      fillColor: kBg,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      border: outlineBorder(13),
      enabledBorder: outlineBorder(13),
      focusedBorder: outlineBorder(13, color: kPrimary, width: 2),
    );
  }

  Widget _buildAlertGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: alertTypes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final alertType = alertTypes[index];

        return _EmergencyCard(
          label: alertType.type,
          icon: alertType.icon,
          isSelected: _selectedType == alertType.type,
          onPressed: () {
            setState(() {
              _selectedType = alertType.type;
            });
          },
        );
      },
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      height: 58,
      child: FilledButton.icon(
        onPressed: _selectedType == null || _sending ? null : _sendAlert,
        style: FilledButton.styleFrom(
          backgroundColor: kPrimary,
          disabledBackgroundColor: kBorder,
          foregroundColor: Colors.white,
          disabledForegroundColor: kTextSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _sending
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Icon(
                Icons.warning_amber_rounded,
                size: 25,
              ),
        label: Text(
          _sending ? 'SENDING...' : 'SEND ALERT',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected
                ? kPrimary.withValues(alpha: 0.08)
                : kSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? kPrimary : kBorder,
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isSelected ? 0.08 : 0.035,
                ),
                blurRadius: isSelected ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: isSelected
                      ? kPrimary
                      : kPrimary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 38,
                  color: isSelected
                      ? Colors.white
                      : kPrimary,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: isSelected
                      ? kPrimary
                      : kTextPrimary,
                ),
              ),

              if (isSelected) ...[
                const SizedBox(height: 6),
                const Text(
                  'SELECTED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: kPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
