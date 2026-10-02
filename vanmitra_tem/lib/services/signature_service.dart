import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/user_role.dart';

/// Digital Signature Service Abstraction for Official Title Authorization
/// (Annexure IV signatories: DFO, DTWO, District Collector)
abstract class ISignatureService {
  Future<String> generateSignatureHash({
    required String claimId,
    required String signerId,
    required UserRole signerRole,
    required DateTime timestamp,
  });

  Future<bool> verifySignature({
    required String claimId,
    required String signerId,
    required UserRole signerRole,
    required DateTime timestamp,
    required String signatureHash,
  });
}

/// Development & Demo Mock Implementation of SignatureService
class SignatureService implements ISignatureService {
  @override
  Future<String> generateSignatureHash({
    required String claimId,
    required String signerId,
    required UserRole signerRole,
    required DateTime timestamp,
  }) async {
    final payload =
        'SIGNATURE_V1:$claimId:$signerId:${signerRole.name}:${timestamp.toIso8601String()}:VANMITRA_SECURE';
    final bytes = utf8.encode(payload);
    final digest = sha256.convert(bytes);
    return 'SIG_SHA256_${digest.toString().substring(0, 16).toUpperCase()}';
  }

  @override
  Future<bool> verifySignature({
    required String claimId,
    required String signerId,
    required UserRole signerRole,
    required DateTime timestamp,
    required String signatureHash,
  }) async {
    final expected = await generateSignatureHash(
      claimId: claimId,
      signerId: signerId,
      signerRole: signerRole,
      timestamp: timestamp,
    );
    return expected == signatureHash;
  }
}
