/// The OFFLINE DEMO build (`--dart-define=VANMITRA_DEMO=all`).
///
/// In this build the app never calls a server: every call the app makes to the VanMitra API is
/// answered inside the phone from the demo "server" in lib/demo/, which keeps its data on the
/// phone. All the logins of the real system work (village user, Gram Sabha, SDO, admin) and new
/// village users can register. The data is SAMPLE data, labelled so wherever it is shown. A normal
/// build has VANMITRA_DEMO empty and is not affected by any of this.
class DemoMode {
  DemoMode._();

  static const String _id = String.fromEnvironment('VANMITRA_DEMO');

  /// Set by tests; a real build reads the compile-time value.
  static String? idForTest;

  static bool get enabled => (idForTest ?? _id).isNotEmpty;
}
