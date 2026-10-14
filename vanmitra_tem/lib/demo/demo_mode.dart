import '../models/user_role.dart';

/// One presenter's offline demo build: who is signed in, and which part of the app opens first.
class DemoPersona {
  const DemoPersona({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.landing,
    required this.tagline,
  });

  final String id;
  final String name;
  final String phone;
  final UserRole role;

  /// Which bottom-bar tab opens after signing in ('home', 'claims', 'map', 'livelihood').
  final String landing;
  final String tagline;

  /// Shown on the sign-in screen and accepted by the demo login.
  static const String pin = '123456';
}

/// The OFFLINE DEMO build (`--dart-define=VANMITRA_DEMO=<persona>`).
///
/// In this build the app never calls a server: every call the app makes to the VanMitra API is
/// answered inside the phone from mock data bundled in the APK (lib/demo/). The data is SAMPLE
/// data, labelled so wherever it is shown. A normal build has VANMITRA_DEMO empty and is not
/// affected by any of this.
class DemoMode {
  DemoMode._();

  static const String _id = String.fromEnvironment('VANMITRA_DEMO');

  static const List<DemoPersona> personas = [
    DemoPersona(
      id: 'samrudhi',
      name: 'Samrudhi',
      phone: '9100000001',
      role: UserRole.villager,
      landing: 'livelihood',
      tagline: 'Livelihood report (Module 4)',
    ),
    DemoPersona(
      id: 'sanskriti',
      name: 'Sanskriti',
      phone: '9100000002',
      role: UserRole.villager,
      landing: 'claims',
      tagline: 'Forest rights claims (Module 1)',
    ),
    DemoPersona(
      id: 'ayush',
      name: 'Ayush',
      phone: '9100000003',
      role: UserRole.villager,
      landing: 'map',
      tagline: 'Atlas map',
    ),
  ];

  /// Set by tests; a real build reads the compile-time value.
  static String? idForTest;

  static String get id => idForTest ?? _id;
  static bool get enabled => id.isNotEmpty;

  static DemoPersona? get persona {
    for (final p in personas) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The persona that owns [phone], or null.
  static DemoPersona? byPhone(String phone) {
    for (final p in personas) {
      if (p.phone == phone) return p;
    }
    return null;
  }
}
