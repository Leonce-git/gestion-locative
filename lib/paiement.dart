import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gestion_locative/locataire.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:gestion_locative/mesBiens.dart';
// import 'package:gestion_locative/locataire.dart';
// import 'package:gestion_locative/document.dart';
// import 'package:gestion_locative/profil_refonte.dart';
// import 'package:gestion_locative/accueil_refonte.dart';

// ─────────────────────────────────────────────
// Palette
// ─────────────────────────────────────────────
class _C {
  static const navy = Color(0xFF1A2B5E);
  static const cream = Color(0xFFF2C94C);
  static const creamLight = Color(0xFFFDF6DC);
  static const bgPage = Color(0xFFF5F0E8);
  static const white = Color(0xFFFFFFFF);
  static const textMain = Color(0xFF1A2B5E);
  static const textMuted = Color(0xFF7A6F52);
  static const border = Color(0xFFECE6D6);

  // Statuts
  static const paidText = Color(0xFF3B6D11);
  static const paidBg = Color(0xFFF0FAE4);
  static const paidBd = Color(0xFFC0DD97);
  static const pendText = Color(0xFF854F0B);
  static const pendBg = Color(0xFFFAEEDA);
  static const pendBd = Color(0xFFF5C97A);
  static const lateText = Color(0xFF993C1D);
  static const lateBg = Color(0xFFFFEBE5);
  static const lateBd = Color(0xFFF5B5A0);
}

// ─────────────────────────────────────────────
// Modèle
// ─────────────────────────────────────────────
enum PayStatus { paye, attente, retard }

class _Payment {
  final String? tenantId;
  final String initials;
  final Color avatarColor;
  final String name;
  final String room;
  final int amount;
  final PayStatus status;

  const _Payment({
    this.tenantId,
    required this.initials,
    required this.avatarColor,
    required this.name,
    required this.room,
    required this.amount,
    required this.status,
  });

  factory _Payment.fromTenant(TenantRecord tenant) {
    return _Payment(
      tenantId: tenant.id,
      initials: tenant.initials,
      avatarColor: tenant.statusColor,
      name: tenant.name,
      room: '${tenant.roomNumber} - ${tenant.propertyName}',
      amount: _amountFromText(tenant.rentAmount),
      status: _statusFromTenant(tenant.statusLabel),
    );
  }

  String get statusLabel {
    switch (status) {
      case PayStatus.paye:
        return 'Payé';
      case PayStatus.attente:
        return 'En attente';
      case PayStatus.retard:
        return 'Retard';
    }
  }

  Color get statusText {
    switch (status) {
      case PayStatus.paye:
        return _C.paidText;
      case PayStatus.attente:
        return _C.pendText;
      case PayStatus.retard:
        return _C.lateText;
    }
  }

  Color get statusBg {
    switch (status) {
      case PayStatus.paye:
        return _C.paidBg;
      case PayStatus.attente:
        return _C.pendBg;
      case PayStatus.retard:
        return _C.lateBg;
    }
  }

  Color get statusBd {
    switch (status) {
      case PayStatus.paye:
        return _C.paidBd;
      case PayStatus.attente:
        return _C.pendBd;
      case PayStatus.retard:
        return _C.lateBd;
    }
  }
}

// ─────────────────────────────────────────────
// Données de démo
// ─────────────────────────────────────────────
final _demoPayments = <_Payment>[
  const _Payment(
    initials: 'AM',
    avatarColor: Color(0xFFF2C94C),
    name: 'Ama Mensah',
    room: 'Chambre A · Calavi',
    amount: 75000,
    status: PayStatus.paye,
  ),
  const _Payment(
    initials: 'KO',
    avatarColor: Color(0xFF2ECC71),
    name: 'Koffi Ouédraogo',
    room: 'Chambre B · Plateau',
    amount: 80000,
    status: PayStatus.attente,
  ),
  const _Payment(
    initials: 'AM',
    avatarColor: Color(0xFF5DADE2),
    name: 'Séraphine Bah',
    room: 'Chambre C · Cadjèhoun',
    amount: 65000,
    status: PayStatus.retard,
  ),
  const _Payment(
    initials: 'DF',
    avatarColor: Color(0xFF9B59B6),
    name: 'Djamal Fofana',
    room: 'Chambre D · Akpakpa',
    amount: 70000,
    status: PayStatus.paye,
  ),
];

int _amountFromText(String value) {
  return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}

// ─────────────────────────────────────────────
// Carte Lien Général (réutilisable)
// ─────────────────────────────────────────────
class _GeneralLinkCard extends StatelessWidget {
  final String link;
  final String adminUid;

  const _GeneralLinkCard({required this.link, required this.adminUid});

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Lien général copié !'),
        backgroundColor: const Color(0xFF149954),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _whatsapp(BuildContext context) async {
    const msg = 'Bonjour, voici le lien pour payer votre loyer en ligne :';
    final text = Uri.encodeComponent('$msg $link');
    final url = Uri.parse('https://wa.me/?text=$text');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) _copy(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (adminUid.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B2E), Color(0xFF1A4480)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.public_rounded, color: Colors.white, size: 16),
              SizedBox(width: 7),
              Text(
                'Lien général — tous les locataires',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Envoyez ce lien à n\'importe quel locataire. Il choisira son nom.',
            style: TextStyle(color: Color(0xFFABC4E0), fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _whatsapp(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_rounded,
                            color: Colors.white, size: 14),
                        SizedBox(width: 5),
                        Text('WhatsApp',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _copy(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.copy_rounded,
                            color: Colors.white, size: 14),
                        SizedBox(width: 5),
                        Text('Copier',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

PayStatus _statusFromTenant(String status) {
  switch (status) {
    case 'A jour':
    case 'Payé':
      return PayStatus.paye;
    case 'Retard':
      return PayStatus.retard;
    default:
      return PayStatus.attente;
  }
}

// ─────────────────────────────────────────────
// Page Paiement
// ─────────────────────────────────────────────
class Paiement extends StatefulWidget {
  final bool showBottomNav;

  const Paiement({super.key, this.showBottomNav = true});

  @override
  State<Paiement> createState() => _PaiementState();
}

class _PaiementState extends State<Paiement> {
  // 0=Tous, 1=Payé, 2=Attente, 3=Retard
  int _filterIndex = 0;
  late List<_Payment> _payments = List.from(_demoPayments);

  List<_Payment> get _filtered {
    switch (_filterIndex) {
      case 1:
        return _payments.where((p) => p.status == PayStatus.paye).toList();
      case 2:
        return _payments.where((p) => p.status == PayStatus.attente).toList();
      case 3:
        return _payments.where((p) => p.status == PayStatus.retard).toList();
      default:
        return _payments;
    }
  }

  int get _totalEncaisse => _payments
      .where((p) => p.status == PayStatus.paye)
      .fold(0, (s, p) => s + p.amount);

  String _fmt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _markPaid(_Payment p) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && p.tenantId != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('locataires')
          .doc(p.tenantId)
          .set({
            'statusLabel': 'A jour',
            'statusColor': const Color(0xFF3B6D11).toARGB32(),
            'balanceLabel': 'Solde a jour',
            'paymentSummary': 'Dernier paiement : ${_fmt(p.amount)} FCFA',
            'lastPaymentAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('paiements')
          .add({
            'tenantId': p.tenantId,
            'tenantName': p.name,
            'amount': p.amount,
            'method': 'Manuel',
            'status': 'paye',
            'createdAt': FieldValue.serverTimestamp(),
          });
    }

    final idx = _payments.indexOf(p);
    if (idx == -1) return;
    // On recrée avec statut payé
    final updated = _Payment(
      initials: p.initials,
      tenantId: p.tenantId,
      avatarColor: p.avatarColor,
      name: p.name,
      room: p.room,
      amount: p.amount,
      status: PayStatus.paye,
    );
    setState(() => _payments[idx] = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${p.name} marqué comme payé ✅'),
        backgroundColor: _C.paidText,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mois courant
    final now = DateTime.now();
    final months = [
      'JAN',
      'FÉV',
      'MAR',
      'AVR',
      'MAI',
      'JUN',
      'JUL',
      'AOÛ',
      'SEP',
      'OCT',
      'NOV',
      'DÉC',
    ];
    final mois = '${months[now.month - 1]} ${now.year}';

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _paymentScaffold(mois, _payments);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('locataires')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final firestorePayments = snapshot.hasData
            ? snapshot.data!.docs
                  .map(
                    (doc) => TenantRecord.fromMap(
                      doc.data() as Map<String, dynamic>,
                    ).copyWith(id: doc.id),
                  )
                  .map(_Payment.fromTenant)
                  .toList()
            : <_Payment>[];
        _payments = firestorePayments;
        return _paymentScaffold(mois, firestorePayments);
      },
    );
  }

  Widget _paymentScaffold(String mois, List<_Payment> payments) {
    final visiblePayments = _filterPayments(payments);
    return Scaffold(
      backgroundColor: _C.bgPage,
      body: Column(
        children: [
          _buildHeader(mois, payments),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Locataires récents', 'Voir tout', () {
                    setState(() => _filterIndex = 0);
                  }),
                  const SizedBox(height: 10),
                  ...visiblePayments.map((p) => _paymentRow(p)),
                  const SizedBox(height: 16),
                  _buildPayCashBtn(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.showBottomNav
          ? _buildBottomNav(context)
          : null,
    );
  }

  List<_Payment> _filterPayments(List<_Payment> payments) {
    switch (_filterIndex) {
      case 1:
        return payments.where((p) => p.status == PayStatus.paye).toList();
      case 2:
        return payments.where((p) => p.status == PayStatus.attente).toList();
      case 3:
        return payments.where((p) => p.status == PayStatus.retard).toList();
      default:
        return payments;
    }
  }

  // ── HEADER ────────────────────────────────────────────
  Widget _buildHeader(String mois, List<_Payment> payments) {
    final totalEncaisse = payments
        .where((p) => p.status == PayStatus.paye)
        .fold(0, (s, p) => s + p.amount);
    return Container(
      color: _C.navy,
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          const Text(
            'Paiement',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Card total encaissé
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _C.creamLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total encaissé-$mois',
                  style: const TextStyle(fontSize: 12, color: _C.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmt(totalEncaisse)} FCFA',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _C.textMain,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Chips filtre
          Row(
            children: [
              _chip('Tous', 0),
              const SizedBox(width: 8),
              _chip('Payé', 1),
              const SizedBox(width: 8),
              _chip('Attente', 2),
              const SizedBox(width: 8),
              _chip('En retard', 3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int index) {
    final active = _filterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _filterIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _C.cream : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? _C.cream : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: active ? _C.navy : Colors.white,
          ),
        ),
      ),
    );
  }

  // ── SECTION HEADER ────────────────────────────────────
  Widget _sectionHeader(String title, String action, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: _C.navy,
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: _C.navy,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Voir tout',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ── LIGNE PAIEMENT ────────────────────────────────────
  Widget _paymentRow(_Payment p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: p.avatarColor,
            child: Text(
              p.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _C.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.room,
                  style: const TextStyle(fontSize: 11, color: _C.textMuted),
                ),
              ],
            ),
          ),
          // Badge + bouton marquer payé
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: p.statusBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.statusBd),
                ),
                child: Text(
                  p.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: p.statusText,
                  ),
                ),
              ),
              if (p.status != PayStatus.paye) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _markPaid(p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _C.navy,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Marquer payé',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── BOUTON PAYÉ CASH ──────────────────────────────────
  Widget _buildPayCashBtn() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () => _showPayCashSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          decoration: BoxDecoration(
            color: _C.cream,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Payé Cash',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _C.navy,
            ),
          ),
        ),
      ),
    );
  }

  void _showPayCashSheet(BuildContext context) {
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayCashSheet(
        payments: _payments,
        adminUid: adminUid,
        onConfirm: (payment, amount) => _recordCashPayment(payment, amount),
      ),
    );
  }

  Future<void> _recordCashPayment(_Payment payment, int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || payment.tenantId == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('paiements')
        .add({
          'tenantId': payment.tenantId,
          'tenantName': payment.name,
          'amount': amount,
          'method': 'Cash',
          'status': 'paye',
          'createdAt': FieldValue.serverTimestamp(),
        });
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('locataires')
        .doc(payment.tenantId)
        .set({
          'statusLabel': 'A jour',
          'statusColor': const Color(0xFF3B6D11).toARGB32(),
          'balanceLabel': 'Solde a jour',
          'paymentSummary': 'Dernier paiement cash : ${_fmt(amount)} FCFA',
          'lastPaymentAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  // ── BOTTOM NAV ────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.white,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 2,
        selectedItemColor: _C.navy,
        unselectedItemColor: _C.textMuted,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        onTap: (i) {
          final routes = [
            '/accueil',
            '/mesBiens',
            '/paiement',
            '/locataire',
            '/profil',
          ];
          if (i == 2) return;
          Navigator.pushReplacementNamed(context, routes[i]);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_outlined),
            activeIcon: Icon(Icons.account_balance),
            label: 'Biens',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_card_outlined),
            activeIcon: Icon(Icons.credit_card),
            label: 'Paiement',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Locataires',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom sheet Payé Cash
// ─────────────────────────────────────────────
class _PayCashSheet extends StatefulWidget {
  final List<_Payment> payments;
  final String adminUid;
  final Future<void> Function(_Payment payment, int amount) onConfirm;

  const _PayCashSheet({
    required this.payments,
    required this.adminUid,
    required this.onConfirm,
  });

  @override
  State<_PayCashSheet> createState() => _PayCashSheetState();
}

class _PayCashSheetState extends State<_PayCashSheet> {
  _Payment? _selected;
  final _montantCtrl = TextEditingController();

  @override
  void dispose() {
    _montantCtrl.dispose();
    super.dispose();
  }

  // Génère le lien de paiement via le code unique du locataire
  String _buildLink(_Payment p) {
    // Le code est stocké dans Firestore — on le récupère via tenantId
    // Pour l'instant on utilise tenantId comme fallback dans le lien général
    // Le locataire saisira son code sur la page
    return 'https://gestion-locative-3f02c.web.app/payer';
  }

  String _buildGeneralLink() {
    return 'https://gestion-locative-3f02c.web.app/payer';
  }

  void _copyLink(String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Lien copié !'),
        backgroundColor: const Color(0xFF149954),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _shareWhatsApp(String link, String name) async {
    final msg = Uri.encodeComponent(
        'Bonjour $name, voici votre lien pour payer votre loyer en ligne : $link');
    final url = Uri.parse('https://wa.me/?text=$msg');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      _copyLink(link);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lien copié (WhatsApp non disponible)'),
            backgroundColor: Color(0xFF607086),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final link = _selected != null ? _buildLink(_selected!) : '';

    return Container(
      decoration: const BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre de glissement
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _C.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payé Cash',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _C.navy,
              ),
            ),
            const SizedBox(height: 16),

            // ── Lien général ────────────────────────────
            _GeneralLinkCard(
              link: _buildGeneralLink(),
              adminUid: widget.adminUid,
            ),
            const SizedBox(height: 16),

            // ── Séparateur ──────────────────────────────
            Row(
              children: [
                const Expanded(child: Divider(color: _C.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou choisir un locataire spécifique',
                    style: TextStyle(
                      color: _C.textMuted.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: _C.border)),
              ],
            ),
            const SizedBox(height: 14),

            // ── Sélection locataire ─────────────────────
            const Text(
              'Locataire',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _C.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _C.creamLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonFormField<_Payment>(
                value: _selected,
                isExpanded: true,
                hint: const Text(
                  'Sélectionner un locataire',
                  style: TextStyle(color: _C.textMuted, fontSize: 14),
                ),
                items: widget.payments
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.textMain,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selected = v;
                    if (v != null) {
                      _montantCtrl.text = v.amount.toString();
                    }
                  });
                },
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                ),
              ),
            ),

            // ── Lien + partage WhatsApp (si locataire sélectionné) ──
            if (_selected != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFB8D4F8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.link_rounded,
                            color: Color(0xFF1F6FEB), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Lien de paiement',
                          style: TextStyle(
                            color: Color(0xFF1F6FEB),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      link,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF607086), fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Bouton WhatsApp
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _shareWhatsApp(
                                link, _selected!.name),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_rounded,
                                      color: Colors.white, size: 15),
                                  SizedBox(width: 6),
                                  Text(
                                    'WhatsApp',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Bouton Copier
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _copyLink(link),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1F6FEB),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.copy_rounded,
                                      color: Colors.white, size: 15),
                                  SizedBox(width: 6),
                                  Text(
                                    'Copier',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Séparateur ───────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    const Expanded(child: Divider(color: _C.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'ou enregistrer directement',
                        style: TextStyle(
                          color: _C.textMuted.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: _C.border)),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 12),

            // ── Montant ─────────────────────────────────
            const Text(
              'Montant (FCFA)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _C.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 14, color: _C.textMain),
              decoration: InputDecoration(
                hintText: 'Ex: 75 000',
                hintStyle: const TextStyle(color: _C.textMuted),
                filled: true,
                fillColor: _C.creamLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFE6A817),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Bouton confirmer ────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (_selected == null) return;
                  final amount =
                      int.tryParse(
                        _montantCtrl.text
                            .replaceAll(RegExp(r'[^0-9]'), ''),
                      ) ??
                      _selected!.amount;
                  final name = _selected!.name;
                  final montantText = _montantCtrl.text;
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  await widget.onConfirm(_selected!, amount);
                  if (!mounted) return;
                  nav.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '$name — $montantText FCFA enregistré',
                      ),
                      backgroundColor: _C.paidText,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.cream,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Confirmer le paiement',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _C.navy,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
