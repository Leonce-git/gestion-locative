import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gestion_locative/app_background.dart';
import 'package:gestion_locative/locataire.dart';
import 'package:gestion_locative/payment_code_service.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class PayeCash extends StatefulWidget {
  const PayeCash({super.key});

  @override
  State<PayeCash> createState() => _PayeCashState();
}

class _PayeCashState extends State<PayeCash> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  TenantRecord? _selectedTenant;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Génère le lien de paiement via code unique ──
  String _paymentLink(TenantRecord tenant) {
    final code = tenant.paymentCode;
    if (code.isNotEmpty) {
      return 'https://gestion-locative-3f02c.web.app/payer?code=$code';
    }
    // Fallback si code pas encore généré
    return 'https://gestion-locative-3f02c.web.app/payer';
  }


  void _copyLink(TenantRecord tenant) {
    Clipboard.setData(ClipboardData(text: _paymentLink(tenant)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lien copié pour ${tenant.name}'),
        backgroundColor: const Color(0xFF149954),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Lien général — le locataire saisira son code sur la page
  String _generalLink() {
    return 'https://gestion-locative-3f02c.web.app/payer';
  }

  void _copyGeneralLink() {
    Clipboard.setData(ClipboardData(text: _generalLink()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lien général copié !'),
        backgroundColor: Color(0xFF149954),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareGeneralWhatsApp() async {
    final link = _generalLink();
    final msg = Uri.encodeComponent(
        'Bonjour, voici le lien pour payer votre loyer en ligne : $link');
    final url = Uri.parse('https://wa.me/?text=$msg');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      _copyGeneralLink();
    }
  }

  Future<void> _shareWhatsApp(TenantRecord tenant) async {
    final link = _paymentLink(tenant);
    final msg = Uri.encodeComponent(
        'Bonjour ${tenant.name}, voici votre lien pour payer votre loyer en ligne : $link');
    final url = Uri.parse('https://wa.me/?text=$msg');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      _copyLink(tenant);
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

  Future<void> _launchPaymentAPI(String provider, TenantRecord tenant) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final tenantId = tenant.id;

    if (currentUser == null || tenantId == null) {
      _showSnack("Impossible d'identifier le paiement.", isError: true);
      return;
    }

    try {
      final url = Uri.parse('https://api.$provider.com/payment');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomNumber': tenant.roomNumber,
          'name': tenant.name,
          'amount': tenant.rentAmount,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('locataires')
            .doc(tenantId)
            .update({
          'statusLabel': 'A jour',
          'paymentSummary':
              'Dernier paiement : ${tenant.rentAmount} le ${DateTime.now()}',
        });

        if (!mounted) return;
        _showSnack('Paiement réussi via $provider');
      } else {
        _showSnack('Erreur paiement via $provider', isError: true);
      }
    } catch (_) {
      if (mounted) _showSnack('Erreur réseau', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFE53935) : const Color(0xFF149954),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF132238).withOpacity(0.06),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF132238),
              size: 18,
            ),
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Paiement Cash',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF132238),
              ),
            ),
            Text(
              'Encaissement & liens de paiement',
              style: TextStyle(fontSize: 13, color: Color(0xFF607086)),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_outlined,
              color: Color(0xFF132238),
            ),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: currentUser == null
              ? const _NotConnected()
              : _PayCashBody(
                  currentUser: currentUser,
                  searchQuery: _searchQuery,
                  searchController: _searchController,
                  selectedTenant: _selectedTenant,
                  onSearchChanged: (v) =>
                      setState(() => _searchQuery = v),
                  onSelectTenant: (t) =>
                      setState(() => _selectedTenant = t),
                  onCopyLink: _copyLink,
                  onShareWhatsApp: _shareWhatsApp,
                  onPay: _launchPaymentAPI,
                  paymentLink: _paymentLink,
                  generalLink: _generalLink(),
                  onCopyGeneralLink: _copyGeneralLink,
                  onShareGeneralWhatsApp: _shareGeneralWhatsApp,
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CORPS PRINCIPAL
// ─────────────────────────────────────────────

class _PayCashBody extends StatelessWidget {
  final User currentUser;
  final String searchQuery;
  final TextEditingController searchController;
  final TenantRecord? selectedTenant;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<TenantRecord> onSelectTenant;
  final ValueChanged<TenantRecord> onCopyLink;
  final ValueChanged<TenantRecord> onShareWhatsApp;
  final Function(String, TenantRecord) onPay;
  final String Function(TenantRecord) paymentLink;
  final String generalLink;
  final VoidCallback onCopyGeneralLink;
  final VoidCallback onShareGeneralWhatsApp;

  const _PayCashBody({
    required this.currentUser,
    required this.searchQuery,
    required this.searchController,
    required this.selectedTenant,
    required this.onSearchChanged,
    required this.onSelectTenant,
    required this.onCopyLink,
    required this.onShareWhatsApp,
    required this.onPay,
    required this.paymentLink,
    required this.generalLink,
    required this.onCopyGeneralLink,
    required this.onShareGeneralWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('locataires')
          .snapshots(),
      builder: (context, snapshot) {
        List<TenantRecord> tenants = [];

        if (snapshot.hasData) {
          tenants = snapshot.data!.docs.map((doc) {
            return TenantRecord.fromMap(
              doc.data() as Map<String, dynamic>,
            ).copyWith(id: doc.id);
          }).toList();

          // Auto-générer les codes manquants pour les locataires existants
          for (final t in tenants) {
            if (t.paymentCode.isEmpty && t.id != null) {
              PaymentCodeService.createForTenant(
                uid: currentUser.uid,
                tenantId: t.id!,
                tenantName: t.name,
              );
            }
          }
        }

        // Fallback aperçu local si pas de données
        if (tenants.isEmpty) tenants = localPreviewTenants;

        // Filtre recherche
        final filtered = searchQuery.isEmpty
            ? tenants
            : tenants
                .where((t) =>
                    t.name
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()) ||
                    t.roomNumber
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()))
                .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── Hero banner ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF102A43),
                    Color(0xFF1F6FEB),
                    Color(0xFF63B3ED),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paiement & Liens',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Encaissez en cash ou partagez un lien de paiement direct à chaque locataire.',
                    style: TextStyle(color: Color(0xFFDDEAF8), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Lien Général ──────────────────────────
            _GeneralLinkBanner(
              link: generalLink,
              onCopy: onCopyGeneralLink,
              onWhatsApp: onShareGeneralWhatsApp,
            ),
            const SizedBox(height: 18),

            // ── Barre de recherche ──
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF132238).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                style: const TextStyle(color: Color(0xFF132238)),
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom ou chambre…',
                  hintStyle: const TextStyle(
                    color: Color(0xFF7D8CA0),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF7D8CA0),
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF7D8CA0), size: 18),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── Compteur ──
            Text(
              '${filtered.length} locataire${filtered.length > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Color(0xFF132238),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),

            // ── Liste des locataires avec liens ──
            if (!snapshot.hasData)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    color: Color(0xFF1F6FEB),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              _EmptySearch()
            else
              ...filtered.map((tenant) => _TenantPayCard(
                    tenant: tenant,
                    isSelected: selectedTenant?.id == tenant.id,
                    link: paymentLink(tenant),
                    onSelect: () => onSelectTenant(tenant),
                    onCopyLink: () => onCopyLink(tenant),
                    onShareWhatsApp: () => onShareWhatsApp(tenant),
                    onPay: (provider) => onPay(provider, tenant),
                  )),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// CARTE LOCATAIRE + LIEN + PAIEMENT
// ─────────────────────────────────────────────

class _TenantPayCard extends StatelessWidget {
  final TenantRecord tenant;
  final bool isSelected;
  final String link;
  final VoidCallback onSelect;
  final VoidCallback onCopyLink;
  final VoidCallback onShareWhatsApp;
  final ValueChanged<String> onPay;

  const _TenantPayCard({
    required this.tenant,
    required this.isSelected,
    required this.link,
    required this.onSelect,
    required this.onCopyLink,
    required this.onShareWhatsApp,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final c = tenant.statusColor;

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1F6FEB)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF132238).withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête locataire ──
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF132238),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        tenant.name.isEmpty
                            ? '?'
                            : tenant.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant.name,
                          style: const TextStyle(
                            color: Color(0xFF132238),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tenant.propertyName} · Ch. ${tenant.roomNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF607086),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // ── Code de paiement ──
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF132238),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tenant.paymentCode.isNotEmpty
                                ? 'Code : ${tenant.paymentCode}'
                                : 'Code en cours…',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge statut + montant
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        tenant.rentAmount,
                        style: const TextStyle(
                          color: Color(0xFF132238),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tenant.statusLabel,
                          style: TextStyle(
                            color: c,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Zone lien de paiement ──
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDDEAF8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // URL tronquée
                    Row(
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          color: Color(0xFF1F6FEB),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            link,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF607086),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Boutons WhatsApp + Copier
                    Row(
                      children: [
                        // WhatsApp
                        Expanded(
                          child: GestureDetector(
                            onTap: onShareWhatsApp,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_rounded,
                                      color: Colors.white, size: 14),
                                  SizedBox(width: 5),
                                  Text(
                                    'WhatsApp',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Copier
                        Expanded(
                          child: GestureDetector(
                            onTap: onCopyLink,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1F6FEB),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.copy_rounded,
                                      color: Colors.white, size: 14),
                                  SizedBox(width: 5),
                                  Text(
                                    'Copier',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
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

              // ── Options de paiement (visibles si sélectionné) ──
              if (isSelected) ...[
                const SizedBox(height: 14),
                const Text(
                  'Choisir un mode de paiement',
                  style: TextStyle(
                    color: Color(0xFF132238),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _PayOption(
                        label: 'MTN MoMo',
                        color: const Color(0xFFFFCC00),
                        textColor: const Color(0xFF132238),
                        icon: Icons.phone_android_rounded,
                        onTap: () => onPay('MTN'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PayOption(
                        label: 'Moov Money',
                        color: const Color(0xFF1F6FEB),
                        textColor: Colors.white,
                        icon: Icons.phone_android_rounded,
                        onTap: () => onPay('Moov'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PayOption(
                        label: 'Celtis Mobile',
                        color: const Color(0xFF00A86B),
                        textColor: Colors.white,
                        icon: Icons.phone_android_rounded,
                        onTap: () => onPay('Celtis'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PayOption(
                        label: 'Banque',
                        color: const Color(0xFF132238),
                        textColor: Colors.white,
                        icon: Icons.account_balance_outlined,
                        onTap: () => onPay('Banque'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// OPTION DE PAIEMENT
// ─────────────────────────────────────────────

class _PayOption extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData icon;
  final VoidCallback onTap;

  const _PayOption({
    required this.label,
    required this.color,
    required this.textColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ÉTATS SPÉCIAUX
// ─────────────────────────────────────────────

class _NotConnected extends StatelessWidget {
  const _NotConnected();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1F6FEB).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  size: 48, color: Color(0xFF1F6FEB)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Connexion requise',
              style: TextStyle(
                color: Color(0xFF132238),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connectez-vous pour accéder aux paiements.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF607086)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF7D8CA0)),
          SizedBox(height: 10),
          Text(
            'Aucun locataire trouvé.',
            style: TextStyle(color: Color(0xFF607086)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bannière Lien Général
// ─────────────────────────────────────────────
class _GeneralLinkBanner extends StatelessWidget {
  final String link;
  final VoidCallback onCopy;
  final VoidCallback onWhatsApp;

  const _GeneralLinkBanner({
    required this.link,
    required this.onCopy,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B2E), Color(0xFF1A4480)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.public_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Lien de paiement général',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Envoyez ce lien unique à n\'importe quel locataire.\nIl choisira son nom et paiera son loyer.',
            style: TextStyle(
              color: Color(0xFFABC4E0),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          // URL tronquée
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded,
                    color: Color(0xFF63B3ED), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    link,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFFDDEAF8), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onWhatsApp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_rounded,
                            color: Colors.white, size: 15),
                        SizedBox(width: 6),
                        Text(
                          'WhatsApp',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onCopy,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.copy_rounded,
                            color: Colors.white, size: 15),
                        SizedBox(width: 6),
                        Text(
                          'Copier',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
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
    );
  }
}
