// Page publique de paiement — accessible sans compte.
// Le locataire saisit son code unique (6 caractères).
// Ses informations s'affichent automatiquement.
// Il choisit le nombre de mois et paie via mobile money ou virement.
//
// URL : https://gestion-locative-3f02c.web.app/pay
// Avec code pré-rempli : /pay?code=XXXXXX

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestion_locative/payment_code_service.dart';

class TenantPaymentPage extends StatefulWidget {
  final String code;
  const TenantPaymentPage({super.key, this.code = ''});

  @override
  State<TenantPaymentPage> createState() => _TenantPaymentPageState();
}

enum _Step { code, info, payment, processing, success }

class _TenantPaymentPageState extends State<TenantPaymentPage>
    with SingleTickerProviderStateMixin {
  _Step _step = _Step.code;

  // Code
  final _codeCtrl = TextEditingController();
  bool _searching = false;
  String? _codeError;

  // Données locataire
  Map<String, dynamic>? _tenant;
  int _foundMonthly = 0;
  bool _isLate = false;

  // Paiement
  int _months = 1;
  String? _payMethod;
  final _phoneCtrl = TextEditingController();
  String? _phoneError;

  int get _total => _foundMonthly * _months;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    if (widget.code.isNotEmpty) {
      _codeCtrl.text = widget.code;
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Recherche par code ──────────────────────────
  Future<void> _lookup() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _codeError = 'Le code doit contenir 6 caractères.');
      return;
    }

    setState(() {
      _searching = true;
      _codeError = null;
    });

    final data = await PaymentCodeService.lookup(code);

    if (!mounted) return;

    if (data == null) {
      setState(() {
        _searching = false;
        _codeError = 'Code introuvable. Vérifiez et réessayez.';
      });
      return;
    }

    final amountRaw =
        (data['rentAmount'] ?? '0').toString().replaceAll(RegExp(r'[^0-9]'), '');
    final monthly = int.tryParse(amountRaw) ?? 0;

    setState(() {
      _searching = false;
      _tenant = data;
      _foundMonthly = monthly;
      _isLate = (data['statusLabel'] ?? '') == 'Retard';
      _step = _Step.info;
    });
    _fadeCtrl.forward(from: 0);
  }

  // ── Lancer la page de paiement ──────────────────
  void _startPayment() {
    if (_payMethod == null) return;
    setState(() => _step = _Step.payment);
  }

  // ── Confirmer le paiement (sandbox) ────────────
  Future<void> _confirmPayment() async {
    if (_payMethod != 'Banque') {
      final phone = _phoneCtrl.text.trim();
      if (phone.length < 8) {
        setState(() => _phoneError = 'Numéro invalide.');
        return;
      }
    }

    setState(() => _step = _Step.processing);

    // Simulation sandbox : 3 secondes
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Enregistrer le paiement dans Firestore
    try {
      final uid = _tenant!['uid'] as String;
      final tenantId = _tenant!['tenantId'] as String;
      final tenantName = _tenant!['name']?.toString() ?? '';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('paiements')
          .add({
        'tenantId': tenantId,
        'tenantName': tenantName,
        'amount': _total,
        'method': _payMethod,
        'status': 'paye',
        'monthsCount': _months,
        'source': 'lien_partage',
        'paymentCode': _tenant!['paymentCode'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (tenantId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('locataires')
            .doc(tenantId)
            .set({
          'statusLabel': 'A jour',
          'statusColor': const Color(0xFF3B6D11).toARGB32(),
          'balanceLabel': 'Solde a jour',
          'paymentSummary': 'Dernier paiement : ${_fmt(_total)} FCFA',
          'lastPaymentAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Ignorer les erreurs Firestore en mode sandbox
    }

    setState(() => _step = _Step.success);
  }

  String _fmt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  // ══════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: SafeArea(
        child: switch (_step) {
          _Step.code => _buildCodeStep(),
          _Step.info => _buildInfoStep(),
          _Step.payment => _buildPaymentStep(),
          _Step.processing => _buildProcessingStep(),
          _Step.success => _buildSuccessStep(),
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // ÉTAPE 1 — Saisie du code
  // ══════════════════════════════════════════════════
  Widget _buildCodeStep() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _header('Paiement de Loyer', 'Entrez votre code unique'),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Code de paiement',
                  style: TextStyle(
                    color: Color(0xFF132238),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1F6FEB).withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF132238),
                      letterSpacing: 8,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9]')),
                    ],
                    onChanged: (v) {
                      setState(() => _codeError = null);
                      if (v.length == 6) _lookup();
                    },
                    decoration: InputDecoration(
                      hintText: 'EX: A3X7KP',
                      hintStyle: TextStyle(
                        color: const Color(0xFF9BAAB8).withValues(alpha: 0.6),
                        letterSpacing: 6,
                        fontSize: 22,
                      ),
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 22),
                    ),
                  ),
                ),

                if (_codeError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBE5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF5B5A0)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFF993C1D), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_codeError!,
                            style: const TextStyle(
                                color: Color(0xFF993C1D), fontSize: 13)),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _searching ? null : _lookup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F6FEB),
                      disabledBackgroundColor: const Color(0xFFB0BEC5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _searching
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Accéder à mon dossier',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            )),
                  ),
                ),

                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Votre code unique vous a été transmis par votre propriétaire.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Color(0xFF9BAAB8), fontSize: 12),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // ÉTAPE 2 — Dossier + sélection paiement
  // ══════════════════════════════════════════════════
  Widget _buildInfoStep() {
    final t = _tenant!;
    final name = t['name']?.toString() ?? '';
    final room = t['roomNumber']?.toString() ?? '';
    final property = t['propertyName']?.toString() ?? '';
    final code = t['paymentCode']?.toString() ?? '';

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _header('Votre dossier', 'Code : $code'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Carte locataire ──────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF1F6FEB)
                              .withValues(alpha: 0.25),
                          width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1F6FEB)
                              .withValues(alpha: 0.07),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(0xFF132238),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                        color: Color(0xFF132238),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      )),
                                  const SizedBox(height: 3),
                                  Text(
                                    [
                                      if (room.isNotEmpty) 'Chambre $room',
                                      if (property.isNotEmpty) property,
                                    ].join(' · '),
                                    style: const TextStyle(
                                        color: Color(0xFF607086),
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            _statusBadge(_isLate),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Divider(
                              height: 1, color: Color(0xFFEEF3F8)),
                        ),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Loyer mensuel',
                                style: TextStyle(
                                    color: Color(0xFF607086),
                                    fontSize: 13)),
                            Row(children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF1F6FEB), size: 16),
                              const SizedBox(width: 5),
                              Text('${_fmt(_foundMonthly)} FCFA',
                                  style: const TextStyle(
                                    color: Color(0xFF132238),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  )),
                            ]),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _sectionLabel('Nombre de mois à payer'),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: _cardDeco(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _circleBtn(Icons.remove_rounded, () {
                          if (_months > 1) setState(() => _months--);
                        }),
                        Column(children: [
                          Text('$_months',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF132238),
                              )),
                          const Text('mois',
                              style: TextStyle(
                                  color: Color(0xFF607086),
                                  fontSize: 12)),
                        ]),
                        _circleBtn(Icons.add_rounded, () {
                          if (_months < 12) setState(() => _months++);
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF102A43), Color(0xFF1F6FEB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total à payer',
                                style: TextStyle(
                                    color: Color(0xFFDDEAF8),
                                    fontSize: 13)),
                            const SizedBox(height: 3),
                            Text(
                                '${_fmt(_foundMonthly)} × $_months mois',
                                style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11)),
                          ],
                        ),
                        Text('${_fmt(_total)} FCFA',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _sectionLabel('Mode de paiement'),
                  const SizedBox(height: 10),

                  _methodTileIcon('MTN MoMo',
                      Icons.phone_android_rounded,
                      const Color(0xFFFFCC00),
                      const Color(0xFF132238),
                      'MTN'),
                  const SizedBox(height: 10),
                  _methodTileIcon('Moov Money',
                      Icons.phone_android_rounded,
                      const Color(0xFF003087), Colors.white, 'Moov'),
                  const SizedBox(height: 10),
                  _methodTileIcon('Celtis Mobile',
                      Icons.phone_android_rounded,
                      const Color(0xFF00A86B), Colors.white, 'Celtis'),
                  const SizedBox(height: 10),
                  _methodTileIcon('Virement bancaire',
                      Icons.account_balance_outlined,
                      const Color(0xFF132238), Colors.white, 'Banque'),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed:
                          _payMethod == null ? null : _startPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF149954),
                        disabledBackgroundColor: const Color(0xFFB0BEC5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Text('PAYER MAINTENANT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text('Mode test (sandbox)',
                        style: TextStyle(
                            color: Color(0xFF9BAAB8), fontSize: 11)),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _step = _Step.code;
                        _tenant = null;
                        _payMethod = null;
                        _months = 1;
                        _codeCtrl.clear();
                      }),
                      child: const Text('Changer de code',
                          style: TextStyle(
                              color: Color(0xFF607086), fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // ÉTAPE 3 — Interface paiement (sandbox)
  // ══════════════════════════════════════════════════
  Widget _buildPaymentStep() {
    final isMobile = _payMethod != 'Banque';
    final methodLabel = switch (_payMethod) {
      'MTN' => 'MTN MoMo',
      'Moov' => 'Moov Money',
      'Celtis' => 'Celtis Mobile',
      _ => 'Virement bancaire',
    };
    final methodColor = switch (_payMethod) {
      'MTN' => const Color(0xFFFFCC00),
      'Moov' => const Color(0xFF003087),
      'Celtis' => const Color(0xFF00A86B),
      _ => const Color(0xFF132238),
    };
    final btnTextColor = methodColor == const Color(0xFFFFCC00)
        ? const Color(0xFF132238)
        : Colors.white;

    return SingleChildScrollView(
      child: Column(
        children: [
          _header(methodLabel, '${_fmt(_total)} FCFA à payer'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Récapitulatif
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: methodColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: methodColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          '$_months mois · ${_tenant!['name']}',
                          style: const TextStyle(
                              color: Color(0xFF132238),
                              fontWeight: FontWeight.w700)),
                      Text('${_fmt(_total)} FCFA',
                          style: const TextStyle(
                            color: Color(0xFF132238),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (isMobile) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDeco(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: methodColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.phone_android_rounded,
                                color: btnTextColor, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(methodLabel,
                              style: TextStyle(
                                color: methodColor ==
                                        const Color(0xFFFFCC00)
                                    ? const Color(0xFF132238)
                                    : methodColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              )),
                        ]),
                        const SizedBox(height: 20),
                        const Text('Numéro de téléphone',
                            style: TextStyle(
                              color: Color(0xFF607086),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          style: const TextStyle(
                              color: Color(0xFF132238),
                              fontSize: 20,
                              fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: '97 XX XX XX',
                            hintStyle: const TextStyle(
                                color: Color(0xFF9BAAB8), fontSize: 18),
                            counterText: '',
                            prefixText: '+229 ',
                            prefixStyle: const TextStyle(
                                color: Color(0xFF132238),
                                fontWeight: FontWeight.w700),
                            filled: true,
                            fillColor: const Color(0xFFF5F8FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: methodColor, width: 1.5),
                            ),
                            errorText: _phoneError,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                          ),
                          onChanged: (_) =>
                              setState(() => _phoneError = null),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(children: [
                            Icon(Icons.info_outline_rounded,
                                color: Color(0xFFB8860B), size: 15),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Vous recevrez une notification sur votre téléphone pour confirmer.',
                                style: TextStyle(
                                    color: Color(0xFF7A5C00),
                                    fontSize: 11),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // ── Virement bancaire ─────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDeco(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.account_balance_outlined,
                              color: Color(0xFF132238), size: 22),
                          SizedBox(width: 10),
                          Text('Coordonnées bancaires',
                              style: TextStyle(
                                color: Color(0xFF132238),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              )),
                        ]),
                        const SizedBox(height: 16),
                        _bankRow('Banque', 'BOA Bénin'),
                        _bankRow('Titulaire', 'Gestion Locative'),
                        _bankRow(
                            'N° Compte', 'BJ0610001234567890123'),
                        _bankRow('Référence',
                            _tenant!['paymentCode']?.toString() ?? ''),
                        _bankRow('Montant', '${_fmt(_total)} FCFA'),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                              text:
                                  'Banque: BOA Bénin\nTitulaire: Gestion Locative\nN°: BJ0610001234567890123\nRef: ${_tenant!['paymentCode']}\nMontant: ${_fmt(_total)} FCFA',
                            ));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Coordonnées copiées !'),
                                backgroundColor:
                                    const Color(0xFF149954),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4FA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.copy_rounded,
                                    color: Color(0xFF607086), size: 15),
                                SizedBox(width: 6),
                                Text('Copier les coordonnées',
                                    style: TextStyle(
                                        color: Color(0xFF607086),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _confirmPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: methodColor ==
                              const Color(0xFFFFCC00)
                          ? methodColor
                          : const Color(0xFF149954),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      isMobile
                          ? 'Confirmer le paiement'
                          : "J'ai effectué le virement",
                      style: TextStyle(
                        color: btnTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _step = _Step.info),
                    child: const Text('← Retour',
                        style: TextStyle(
                            color: Color(0xFF607086), fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // ÉTAPE 4 — Traitement (simulation)
  // ══════════════════════════════════════════════════
  Widget _buildProcessingStep() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                  color: Color(0xFF1F6FEB), strokeWidth: 4),
            ),
            SizedBox(height: 28),
            Text('Traitement en cours…',
                style: TextStyle(
                  color: Color(0xFF132238),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                )),
            SizedBox(height: 8),
            Text('Ne fermez pas cette page.',
                style:
                    TextStyle(color: Color(0xFF9BAAB8), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // ÉTAPE 5 — Succès
  // ══════════════════════════════════════════════════
  Widget _buildSuccessStep() {
    final tenantName = _tenant?['name']?.toString() ?? '';
    final code = _tenant?['paymentCode']?.toString() ?? '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF3B6D11).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF3B6D11), size: 72),
            ),
            const SizedBox(height: 24),
            const Text('Paiement confirmé !',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF132238),
                )),
            const SizedBox(height: 10),
            Text('${_fmt(_total)} FCFA',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F6FEB),
                )),
            const SizedBox(height: 6),
            Text('$tenantName · $_months mois · $_payMethod',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF607086), fontSize: 14)),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAE4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC0DD97)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_rounded,
                      color: Color(0xFF3B6D11), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Votre paiement a été enregistré. Votre propriétaire sera notifié.',
                      style: TextStyle(
                          color: Color(0xFF3B6D11), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                final receipt =
                    'REÇU DE PAIEMENT\n'
                    '─────────────────\n'
                    'Locataire : $tenantName\n'
                    'Code : $code\n'
                    'Montant : ${_fmt(_total)} FCFA\n'
                    'Mois payés : $_months\n'
                    'Mode : $_payMethod\n'
                    '─────────────────';
                Clipboard.setData(ClipboardData(text: receipt));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Reçu copié !'),
                    backgroundColor: const Color(0xFF3B6D11),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              icon: const Icon(Icons.receipt_long_rounded, size: 17),
              label: const Text('Copier le reçu'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1F6FEB),
                side: const BorderSide(color: Color(0xFF1F6FEB)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────── Helpers visuels ──────────────
  Widget _header(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF102A43), Color(0xFF1F6FEB), Color(0xFF63B3ED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.home_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  color: Color(0xFFDDEAF8), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _statusBadge(bool isLate) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isLate
              ? const Color(0xFFFFEBE5)
              : const Color(0xFFF0FAE4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLate
                ? const Color(0xFFF5B5A0)
                : const Color(0xFFC0DD97),
          ),
        ),
        child: Text(
          isLate ? 'En retard' : 'À jour',
          style: TextStyle(
            color: isLate
                ? const Color(0xFF993C1D)
                : const Color(0xFF3B6D11),
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      );

  Widget _sectionLabel(String t) => Text(t,
      style: const TextStyle(
        color: Color(0xFF132238),
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ));

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8),
        ],
      );

  Widget _circleBtn(IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFF1F6FEB),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      );

  Widget _methodTileIcon(String label, IconData icon, Color bg,
      Color textColor, String method) {
    final selected = _payMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _payMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? bg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? bg : const Color(0xFFE0E8F0),
              width: selected ? 2 : 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? textColor : const Color(0xFF607086),
                size: 22),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                  color: selected ? textColor : const Color(0xFF132238),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                )),
            const Spacer(),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: textColor, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _bankRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF607086), fontSize: 12)),
            Text(value,
                style: const TextStyle(
                  color: Color(0xFF132238),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                )),
          ],
        ),
      );
}
