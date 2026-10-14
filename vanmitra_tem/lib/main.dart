import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firebase_options.dart';
import 'data/local/hive_database.dart';
import 'models/notice.dart';
import 'providers/notices_provider.dart';
import 'services/cloud_sync_service.dart';
import 'app.dart';
import 'widgets/livelihood_host_frame.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Initialize Firebase first
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 2. Configure Firestore offline persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Lock to portrait orientation
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Initialize Hive local database
    await HiveDatabase.initialize();
    
    // Request FCM permission and save token
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null && FirebaseAuth.instance.currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({
          'deviceTokens': FieldValue.arrayUnion([token])
        });
      }
    } catch (_) {} // Non-fatal if FCM setup fails

    // Add Connectivity listener for Cloud Sync (mobile)
    Connectivity().onConnectivityChanged.listen((results) {
      // newer connectivity_plus returns List<ConnectivityResult>
      if (results.any((r) => r != ConnectivityResult.none)) {
        CloudSyncService().syncPendingItems();
      }
    });

    // IMPORTANT: On Chrome/Web, onConnectivityChanged never fires.
    // Always trigger sync immediately on startup to flush the queue.
    CloudSyncService().syncPendingItems();

    // Seed two startup notices so the notice board has visible content
    final container = ProviderContainer(overrides: livelihoodHostOverrides);
    final noticesNotifier = container.read(noticesProvider.notifier);
    await noticesNotifier.loadNotices();
    // Seed a default info notice if board is empty
    final noticesState = container.read(noticesProvider);
    if (noticesState.notices.isEmpty) {
      await noticesNotifier.postAdminNotice(
        titleMr: 'VanMitra-AI मध्ये आपले स्वागत आहे',
        titleEn: 'Welcome to VanMitra-AI',
        bodyMr: 'आता वन हक्क दावे ऑनलाइन दाखल करा आणि AI पडताळणी करा.',
        bodyEn: 'File Forest Rights claims and verify evidence with AI assistance.',
        category: NoticeCategory.general,
        severity: NoticeSeverity.info,
        validUntil: DateTime.now().add(const Duration(days: 30)),
      );
    }

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const VanMitraApp(),
      ),
    );
  } catch (e, stack) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Initialization Error:\n\n$e\n\n$stack',
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
