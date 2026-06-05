import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

// Service de gestion des codes de paiement uniques.
// Collection Firestore : /payment_codes/{code}
// { uid, tenantId, name, createdAt }

class PaymentCodeService {
  // Caractères sans ambiguïté visuelle (pas de 0/O, 1/I/L)
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _rng = Random.secure();

  // ── Génère un code 6 caractères ──────────────────
  static String _generate() =>
      List.generate(6, (_) => _chars[_rng.nextInt(_chars.length)]).join();

  // ── Crée un code unique et l'associe au locataire ─
  static Future<String> createForTenant({
    required String uid,
    required String tenantId,
    required String tenantName,
  }) async {
    // Boucle jusqu'à trouver un code non utilisé
    String code;
    do {
      code = _generate();
    } while ((await FirebaseFirestore.instance
                .collection('payment_codes')
                .doc(code)
                .get())
            .exists);

    // Enregistrer dans la collection racine payment_codes
    await FirebaseFirestore.instance
        .collection('payment_codes')
        .doc(code)
        .set({
      'uid': uid,
      'tenantId': tenantId,
      'name': tenantName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Mettre à jour le locataire avec son code
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('locataires')
        .doc(tenantId)
        .update({'paymentCode': code});

    return code;
  }

  // ── Recherche un locataire par son code ──────────
  // Retourne { uid, tenantId, name, roomNumber, propertyName,
  //            rentAmount, statusLabel, paymentCode }
  // ou null si introuvable.
  static Future<Map<String, dynamic>?> lookup(String code) async {
    final upper = code.trim().toUpperCase();
    if (upper.length != 6) return null;

    final codeSnap = await FirebaseFirestore.instance
        .collection('payment_codes')
        .doc(upper)
        .get();

    if (!codeSnap.exists) return null;

    final meta = codeSnap.data()!;
    final uid = meta['uid'] as String? ?? '';
    final tenantId = meta['tenantId'] as String? ?? '';
    if (uid.isEmpty || tenantId.isEmpty) return null;

    final tenantSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('locataires')
        .doc(tenantId)
        .get();

    if (!tenantSnap.exists) return null;

    return {
      'uid': uid,
      'tenantId': tenantId,
      'paymentCode': upper,
      ...tenantSnap.data()!,
    };
  }

  // ── Génère les codes manquants pour tous les locataires d'un admin ──
  static Future<int> ensureCodesForAll(String uid) async {
    int generated = 0;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('locataires')
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final existing = data['paymentCode']?.toString() ?? '';
      if (existing.isEmpty) {
        await createForTenant(
          uid: uid,
          tenantId: doc.id,
          tenantName: data['name']?.toString() ?? '',
        );
        generated++;
      }
    }
    return generated;
  }
}
