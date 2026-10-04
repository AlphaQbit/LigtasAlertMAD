import 'package:flutter/material.dart';

const kPrimary = Color(0xFFEF4444);
const kBorder = Color(0xFFE5E7EB);
const kTextPrimary = Color(0xFF1F2937);
const kTextSecondary = Color(0xFF6B7280);
const kSurface = Color(0xFFFFFFFF);
const kBg = Color(0xFFF9FAFB);
const kOkBg = Color(0xFFDCFCE7);
const kOkDot = Color(0xFF16A34A);
const kOkText = Color(0xFF15803D);

OutlineInputBorder outlineBorder(double radius, {Color color = kBorder, double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: color, width: width),
    );

const alertTypes = <({String type, IconData icon})>[
  (type: 'Lockdown', icon: Icons.lock),
  (type: 'Fire', icon: Icons.local_fire_department),
  (type: 'Medical', icon: Icons.local_hospital),
  (type: 'Evacuation', icon: Icons.exit_to_app),
];

const facilities = <({String id, String label})>[
  (id: 'building-a', label: 'MCC MAIN'),
  (id: 'building-b', label: 'MCC MADAPDAP'),
  (id: 'campus', label: 'Campus'),
];

// Where the Laravel backend lives.
//
// localhost works for Chrome and desktop. An Android emulator needs the host
// alias instead, and a physical phone needs your machine's LAN address:
//
//   flutter run -d chrome                                  -> localhost
//   flutter run --dart-define=LIGTAS_API_BASE=http://10.0.2.2:8000   (emulator)
//   flutter run --dart-define=LIGTAS_API_BASE=http://192.168.1.5:8000 (phone)
//
// ponytail: one constant, overridden at build time. Move to a real env
// config package only once you are deploying to actual users.
const String kApiBase = String.fromEnvironment(
  'LIGTAS_API_BASE',
  defaultValue: 'http://localhost:8000',
);

// Alert lifecycle, mirroring Alert::TRANSITIONS on the Laravel side.
const String kStatusActive = 'active';
const String kStatusResponding = 'responding';
const String kStatusAcknowledged = 'acknowledged';
const String kStatusResolved = 'resolved';

/// Human-readable status for the rescuee, in the app's own voice.
const Map<String, String> kStatusMessages = {
  kStatusActive: 'Help is on the way. Stay where you are.',
  kStatusResponding: 'Responders are on their way to you.',
  kStatusAcknowledged: 'Your alert was received. Responders are responding.',
  kStatusResolved: 'This emergency has been resolved. Stay safe.',
};