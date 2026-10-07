import 'dart:async';

import 'package:flutter/material.dart';

import 'constants.dart';
import 'services/alert_api.dart';

/// Shown after a rescuee sends an alert. Polls the backend so the rescuer's
/// acknowledgements and status changes show up here without a refresh.
///
/// ponytail: 5s polling, matching the dashboard. There is no WebSocket
/// server on the Laravel side; if you add Reverb/Echo, replace the timer in
/// _poll with a subscription and this becomes push instead of pull.
class AlertStatusPage extends StatefulWidget {
  const AlertStatusPage({super.key, required this.alert, this.api});

  final Alert alert;
  final AlertApi? api;

  @override
  State<AlertStatusPage> createState() => _AlertStatusPageState();
}

class _AlertStatusPageState extends State<AlertStatusPage> {
  static const _pollInterval = Duration(seconds: 5);

  late Alert _alert;
  late final AlertApi _api;
  Timer? _timer;
  bool _showConnectionWarning = false;

  @override
  void initState() {
    super.initState();
    _alert = widget.alert;
    _api = widget.api ?? AlertApi();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Only close a client this page made; HomePage owns the shared one.
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final updated = await _api.fetchAlert(_alert.id);
      if (!mounted) return;

      final changed = updated.status != _alert.status;
      setState(() {
        _alert = updated;
        _showConnectionWarning = false;
      });

if (changed && updated.status == kStatusResolved) {
        _timer?.cancel();
        _timer = null;
      }
    } on AlertApiException {
      if (!mounted) return;
      // Keep the last known state on screen; just say the link is flaky.
      setState(() => _showConnectionWarning = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Alert Sent',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 18),
              if (_showConnectionWarning) _buildConnectionWarning(),
              if (_showConnectionWarning) const SizedBox(height: 18),
              _buildDetailsCard(),
              const SizedBox(height: 18),
              _buildSteps(),
              const SizedBox(height: 24),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final resolved = _alert.status == kStatusResolved;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: resolved ? kOkDot : kPrimary, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              color: resolved ? kOkBg : kPrimary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              resolved ? Icons.check_circle_rounded : Icons.notifications_active_rounded,
              size: 38,
              color: resolved ? kOkDot : kPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _statusTitle(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            kStatusMessages[_alert.status] ?? 'Your alert is being handled.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: kTextSecondary, height: 1.4),
          ),
          if (!resolved) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary),
                ),
                const SizedBox(width: 10),
                // Flexible so the label can wrap instead of overflowing.
                Flexible(
                  child: Text(
                    'Updating automatically...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: kTextSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _statusTitle() => switch (_alert.status) {
        kStatusActive => 'Alert Sent',
        kStatusResponding => 'Responders Dispatched',
        kStatusAcknowledged => 'Help Is On The Way',
        kStatusResolved => 'Resolved',
        _ => 'Alert Sent',
      };

  Widget _buildConnectionWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFB45309), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Lost connection to the rescue service. Still trying...',
              style: TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR ALERT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _detailRow('Type', _alert.type),
          _detailRow('Facility', _alert.facility),
          _detailRow('Location', _alert.location),
          _detailRow('Reference', '#${_alert.id}'),
          if (_alert.responseSeconds != null)
            _detailRow('Response time', '${_alert.responseSeconds}s'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: kTextSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: kTextPrimary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps() {
    const order = [kStatusActive, kStatusResponding, kStatusAcknowledged, kStatusResolved];
    const labels = {
      kStatusActive: 'Alert sent',
      kStatusResponding: 'Responders dispatched',
      kStatusAcknowledged: 'Acknowledged',
      kStatusResolved: 'Resolved',
    };

    final currentIndex = order.indexOf(_alert.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROGRESS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < order.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    i <= currentIndex ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    size: 20,
                    color: i <= currentIndex ? kOkDot : kBorder,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      labels[order[i]]!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: i == currentIndex ? FontWeight.w800 : FontWeight.w500,
                        color: i <= currentIndex ? kTextPrimary : kTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: kPrimary,
        side: const BorderSide(color: kPrimary, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text(
        'Back',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    );
  }
}