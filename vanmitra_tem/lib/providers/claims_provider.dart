import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/local/hive_database.dart';
import '../models/claim.dart';
import '../models/sync_item.dart';
import '../models/user_role.dart';
import '../services/firestore_service.dart';
import '../services/cloud_sync_service.dart';
import 'package:uuid/uuid.dart';

/// Claims state
class ClaimsState {
  final List<Claim> claims;
  final bool isLoading;

  const ClaimsState({this.claims = const [], this.isLoading = false});

  ClaimsState copyWith({List<Claim>? claims, bool? isLoading}) {
    return ClaimsState(
      claims: claims ?? this.claims,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<Claim> get approvedClaims =>
      claims.where((c) => c.status.isApproved).toList();
  List<Claim> get pendingClaims =>
      claims.where((c) => c.status.isPending).toList();
  int get totalApprovedArea =>
      approvedClaims.fold<int>(0, (s, c) => s + (c.areaSqMeters?.toInt() ?? 0));
}

class ClaimsNotifier extends StateNotifier<ClaimsState> {
  ClaimsNotifier() : super(const ClaimsState());

  Future<void> loadClaims(String villageId) async {
    state = state.copyWith(isLoading: true);
    final box = Hive.box<Map>(HiveDatabase.claimsBox);

    final claims = box.values
        .map((v) => Claim.fromJson(Map<String, dynamic>.from(v)))
        .where((c) => c.villageId == villageId)
        .toList();

    state = ClaimsState(claims: claims);
  }

  Future<void> addClaim(Claim claim) async {
    final box = Hive.box<Map>(HiveDatabase.claimsBox);
    await box.put(claim.id, claim.toJson());
    state = state.copyWith(claims: [...state.claims, claim]);

    // Enqueue sync item
    final syncBox = Hive.box<Map>(HiveDatabase.syncQueueBox);
    final syncItem = SyncItem(
      id: const Uuid().v4(),
      action: SyncAction.createClaim,
      status: SyncStatus.pending,
      entityId: claim.id,
      entityType: 'claim',
      payload: claim.toJson(),
      createdAt: DateTime.now(),
    );
    await syncBox.put(syncItem.id, syncItem.toJson());
    CloudSyncService().syncPendingItems().catchError((_) {});
  }

  Future<void> updateClaim(Claim claim) async {
    final box = Hive.box<Map>(HiveDatabase.claimsBox);
    await box.put(claim.id, claim.toJson());
    final updated =
        state.claims.map((c) => c.id == claim.id ? claim : c).toList();
    state = state.copyWith(claims: updated);

    // Enqueue sync item
    final syncBox = Hive.box<Map>(HiveDatabase.syncQueueBox);
    final syncItem = SyncItem(
      id: const Uuid().v4(),
      action: SyncAction.updateClaim,
      status: SyncStatus.pending,
      entityId: claim.id,
      entityType: 'claim',
      payload: claim.toJson(),
      createdAt: DateTime.now(),
    );
    await syncBox.put(syncItem.id, syncItem.toJson());
    CloudSyncService().syncPendingItems().catchError((_) {});
  }
}

final claimsProvider =
    StateNotifierProvider<ClaimsNotifier, ClaimsState>((ref) {
  return ClaimsNotifier();
});

/// Real-time stream of ALL claims for a village (admin / monitoring view).
final claimsStreamProvider =
    StreamProvider.family<List<Claim>, String>((ref, villageId) {
  return FirestoreService().streamClaims(villageId).map((snapshot) =>
      snapshot.docs.map((d) => Claim.fromJson(d.data() as Map<String, dynamic>)).toList());
});

/// Real-time stream of claims filtered to the current user only.
final userClaimsStreamProvider = StreamProvider<List<Claim>>((ref) {
  final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
  if (uid.isEmpty) return Stream.value([]);
  return FirestoreService()
      .streamUserClaims(uid)
      .map((snapshot) => snapshot.docs
          .map((d) => Claim.fromJson(d.data() as Map<String, dynamic>))
          .toList())
      .handleError((_) => <Claim>[]);
});

/// Real-time stream of claims assigned to a specific role/authority.
final roleClaimsStreamProvider =
    StreamProvider.family<List<Claim>, UserRole>((ref, role) {
  return FirestoreService().streamClaims('ozhar_jawhar_palghar').map((snapshot) {
    final list = snapshot.docs
        .map((d) => Claim.fromJson(d.data() as Map<String, dynamic>))
        .toList();
    if (role == UserRole.slmc || role == UserRole.admin) return list;
    return list.where((c) => c.assignedAuthority == role).toList();
  }).handleError((_) => <Claim>[]);
});
