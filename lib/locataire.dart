import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TenantDocument {
  final String title;
  final String reference;
  final String dateLabel;
  final String state;

  const TenantDocument({
    required this.title,
    required this.reference,
    required this.dateLabel,
    required this.state,
  });

  factory TenantDocument.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const TenantDocument.empty();
    return TenantDocument(
      title: map['title']?.toString() ?? '',
      reference: map['reference']?.toString() ?? '',
      dateLabel: map['dateLabel']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
    );
  }

  const TenantDocument.empty()
    : title = '',
      reference = '',
      dateLabel = '',
      state = '';

  Map<String, dynamic> toMap() => {
    'title': title,
    'reference': reference,
    'dateLabel': dateLabel,
    'state': state,
  };
}

class TenantRecord {
  final String? id;
  final String name;
  final String roomNumber;
  final String propertyName;
  final String phone;
  final String email;
  final String rentAmount;
  final String statusLabel;
  final Color statusColor;
  final String balanceLabel;
  final String occupationLabel;
  final TenantDocument contract;
  final TenantDocument inventory;
  final String paymentSummary;
  final String notes;
  final String emergencyContact;
  final String paymentCode;

  const TenantRecord({
    this.id,
    required this.name,
    required this.roomNumber,
    required this.propertyName,
    required this.phone,
    required this.email,
    required this.rentAmount,
    required this.statusLabel,
    required this.statusColor,
    required this.balanceLabel,
    required this.occupationLabel,
    required this.contract,
    required this.inventory,
    required this.paymentSummary,
    required this.notes,
    required this.emergencyContact,
    this.paymentCode = '',
  });

  factory TenantRecord.fromMap(Map<String, dynamic> map) {
    return TenantRecord(
      id: map['id']?.toString(),
      name: map['name']?.toString() ?? map['nom']?.toString() ?? '',
      roomNumber:
          map['roomNumber']?.toString() ?? map['chambre']?.toString() ?? '',
      propertyName:
          map['propertyName']?.toString() ?? map['bien']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      rentAmount: map['rentAmount']?.toString() ?? '0 FCFA',
      statusLabel: map['statusLabel']?.toString() ?? 'A jour',
      statusColor:
          _colorFromValue(map['statusColor']) ??
          _statusColorFor(map['statusLabel']?.toString() ?? 'A jour'),
      balanceLabel: map['balanceLabel']?.toString() ?? '',
      occupationLabel: map['occupationLabel']?.toString() ?? '',
      contract: TenantDocument.fromMap(
        map['contract'] as Map<String, dynamic>?,
      ),
      inventory: TenantDocument.fromMap(
        map['inventory'] as Map<String, dynamic>?,
      ),
      paymentSummary: map['paymentSummary']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      emergencyContact: map['emergencyContact']?.toString() ?? '',
      paymentCode: map['paymentCode']?.toString() ?? '',
    );
  }

  TenantRecord copyWith({
    String? id,
    String? name,
    String? roomNumber,
    String? propertyName,
    String? phone,
    String? email,
    String? rentAmount,
    String? statusLabel,
    Color? statusColor,
    String? balanceLabel,
    String? occupationLabel,
    TenantDocument? contract,
    TenantDocument? inventory,
    String? paymentSummary,
    String? notes,
    String? emergencyContact,
    String? paymentCode,
  }) {
    return TenantRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      roomNumber: roomNumber ?? this.roomNumber,
      propertyName: propertyName ?? this.propertyName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      rentAmount: rentAmount ?? this.rentAmount,
      statusLabel: statusLabel ?? this.statusLabel,
      statusColor: statusColor ?? this.statusColor,
      balanceLabel: balanceLabel ?? this.balanceLabel,
      occupationLabel: occupationLabel ?? this.occupationLabel,
      contract: contract ?? this.contract,
      inventory: inventory ?? this.inventory,
      paymentSummary: paymentSummary ?? this.paymentSummary,
      notes: notes ?? this.notes,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      paymentCode: paymentCode ?? this.paymentCode,
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join();
    return letters.isEmpty ? '?' : letters.toUpperCase();
  }

  String get firstName {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.length > 1 ? parts.skip(1).join(' ') : '';
  }

  String get lastName {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.isEmpty ? '' : parts.first;
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'roomNumber': roomNumber,
    'propertyName': propertyName,
    'phone': phone,
    'email': email,
    'rentAmount': rentAmount,
    'statusLabel': statusLabel,
    'statusColor': statusColor.toARGB32(),
    'balanceLabel': balanceLabel,
    'occupationLabel': occupationLabel,
    'contract': contract.toMap(),
    'inventory': inventory.toMap(),
    'paymentSummary': paymentSummary,
    'notes': notes,
    'emergencyContact': emergencyContact,
    'paymentCode': paymentCode,
  };
}

const localPreviewTenants = [
  TenantRecord(
    id: 'demo-1',
    name: 'Ama Mensah',
    roomNumber: 'A',
    propertyName: 'Residence Calavi',
    phone: '+229 01 90 00 00 01',
    email: 'ama@example.com',
    rentAmount: '70 000 FCFA',
    statusLabel: 'A jour',
    statusColor: Color(0xFF3B6D11),
    balanceLabel: 'Solde a jour',
    occupationLabel: 'Occupe depuis janvier 2026',
    contract: TenantDocument(
      title: 'Contrat A',
      reference: 'CTR-A-2026',
      dateLabel: '05 janvier 2026',
      state: 'Signe',
    ),
    inventory: TenantDocument(
      title: 'Etat des lieux A',
      reference: 'EDL-A-2026',
      dateLabel: '05 janvier 2026',
      state: 'Signe',
    ),
    paymentSummary: 'Dernier paiement : 70 000 FCFA',
    notes: 'Locataire a jour.',
    emergencyContact: 'Contact urgence : +229 01 90 00 00 02',
  ),
  TenantRecord(
    id: 'demo-2',
    name: 'Koffi Ouedraogo',
    roomNumber: 'B',
    propertyName: 'Appartement Plateau',
    phone: '+229 01 91 00 00 01',
    email: 'koffi@example.com',
    rentAmount: '80 000 FCFA',
    statusLabel: 'Paiement attendu',
    statusColor: Color(0xFF854F0B),
    balanceLabel: 'Paiement attendu',
    occupationLabel: 'Occupe depuis fevrier 2026',
    contract: TenantDocument(
      title: 'Contrat B',
      reference: 'CTR-B-2026',
      dateLabel: '12 fevrier 2026',
      state: 'A suivre',
    ),
    inventory: TenantDocument(
      title: 'Etat des lieux B',
      reference: 'EDL-B-2026',
      dateLabel: '12 fevrier 2026',
      state: 'Signe',
    ),
    paymentSummary: 'Paiement du mois attendu',
    notes: 'Relance douce a programmer.',
    emergencyContact: 'Contact urgence non renseigne',
  ),
  TenantRecord(
    id: 'demo-3',
    name: 'Seraphine Bah',
    roomNumber: 'C',
    propertyName: 'Studio Cadjehoun',
    phone: '+229 01 92 00 00 01',
    email: 'seraphine@example.com',
    rentAmount: '65 000 FCFA',
    statusLabel: 'Retard',
    statusColor: Color(0xFF993C1D),
    balanceLabel: 'Relance requise',
    occupationLabel: 'Occupe depuis mars 2026',
    contract: TenantDocument(
      title: 'Contrat C',
      reference: 'CTR-C-2026',
      dateLabel: '20 mars 2026',
      state: 'Signe',
    ),
    inventory: TenantDocument(
      title: 'Etat des lieux C',
      reference: 'EDL-C-2026',
      dateLabel: '20 mars 2026',
      state: 'Brouillon',
    ),
    paymentSummary: 'Retard de paiement',
    notes: 'Appeler avant le 5 du mois.',
    emergencyContact: 'Contact urgence : +229 01 92 00 00 02',
  ),
];

class LocatairesScreen extends StatefulWidget {
  final bool showBottomNav;

  const LocatairesScreen({super.key, this.showBottomNav = true});

  @override
  State<LocatairesScreen> createState() => _LocatairesScreenState();
}

class _LocatairesScreenState extends State<LocatairesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<TenantRecord> _tenants = List.of(localPreviewTenants);
  String _query = '';

  List<TenantRecord> get _filtered {
    if (_query.trim().isEmpty) return _tenants;
    final q = _query.toLowerCase();
    return _tenants
        .where(
          (t) =>
              t.name.toLowerCase().contains(q) ||
              t.roomNumber.toLowerCase().contains(q) ||
              t.propertyName.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2B5E),
        foregroundColor: Colors.white,
        title: const Text('Locataires'),
        actions: [
          IconButton(
            tooltip: 'Ajouter',
            onPressed: () => _addTenant(context),
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Rechercher un locataire',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildTenantList()),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? _BottomNav(
              currentIndex: 3,
              onTap: (index) => _goToTab(context, index),
            )
          : null,
    );
  }

  void _goToTab(BuildContext context, int index) {
    final routes = [
      '/accueil',
      '/mesBiens',
      '/paiement',
      '/locataire',
      '/profil',
    ];
    if (index == 3) return;
    Navigator.pushReplacementNamed(context, routes[index]);
  }

  Future<void> _addTenant(BuildContext context) async {
    final result = await Navigator.pushNamed(context, '/ajoutLocataire');
    if (result is TenantRecord) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Not authenticated — keep a local preview copy so the UI updates.
        setState(() => _tenants.insert(0, result));
      }
      // If authenticated, the Ajout screen already persisted the tenant to Firestore.
      // The StreamBuilder in this screen will pick up the new document; avoid duplicate writes.
    }
  }

  Widget _buildTenantList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _tenantList(_filtered);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('locataires')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final tenants = snapshot.hasData
            ? snapshot.data!.docs
                  .map(
                    (doc) => TenantRecord.fromMap(
                      doc.data() as Map<String, dynamic>,
                    ).copyWith(id: doc.id),
                  )
                  .toList()
            : <TenantRecord>[];
        // Deduplicate tenants by (name, roomNumber, propertyName) to avoid duplicate
        // documents showing twice. Keep the first occurrence (stream is ordered by
        // createdAt descending, so first is most recent).
        final uniqueMap = <String, TenantRecord>{};
        for (final t in tenants) {
          final key = '${t.name.toLowerCase()}|${t.roomNumber.toLowerCase()}|${t.propertyName.toLowerCase()}';
          if (!uniqueMap.containsKey(key)) uniqueMap[key] = t;
        }
        final uniqueTenants = uniqueMap.values.toList();
        final q = _query.toLowerCase();
        final filtered = q.isEmpty
            ? uniqueTenants
            : uniqueTenants
                  .where(
                    (t) =>
                        t.name.toLowerCase().contains(q) ||
                        t.roomNumber.toLowerCase().contains(q) ||
                        t.propertyName.toLowerCase().contains(q),
                  )
                  .toList();
        return _tenantList(filtered, firestoreUserId: user.uid);
      },
    );
  }

  Widget _tenantList(List<TenantRecord> tenants, {String? firestoreUserId}) {
    if (tenants.isEmpty) {
      return const Center(child: Text('Aucun locataire trouve.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: tenants.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final tenant = tenants[index];
        return _TenantCard(
          tenant: tenant,
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TenantDetailScreen(tenant: tenant),
            ),
          ),
          onDelete: () async {
            if (firestoreUserId != null && tenant.id != null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(firestoreUserId)
                  .collection('locataires')
                  .doc(tenant.id)
                  .delete();
            } else {
              setState(() => _tenants.removeWhere((t) => t.id == tenant.id));
            }
          },
        );
      },
    );
  }
}

class _TenantCard extends StatelessWidget {
  final TenantRecord tenant;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _TenantCard({
    required this.tenant,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFECE6D6)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: tenant.statusColor,
                child: Text(
                  tenant.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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
                        color: Color(0xFF1A2B5E),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Chambre ${tenant.roomNumber} - ${tenant.propertyName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF7A6F52)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tenant.rentAmount,
                      style: const TextStyle(
                        color: Color(0xFF1A2B5E),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: tenant.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tenant.statusLabel,
                      style: TextStyle(
                        color: tenant.statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFF993C1D),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TenantDetailScreen extends StatelessWidget {
  final TenantRecord tenant;

  const TenantDetailScreen({super.key, required this.tenant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2B5E),
        foregroundColor: Colors.white,
        title: Text(tenant.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DetailHeader(tenant: tenant),
          const SizedBox(height: 14),
          _DetailSection(
            title: 'Informations',
            children: [
              _InfoRow(label: 'Nom', value: tenant.lastName),
              _InfoRow(
                label: 'Prenom',
                value: tenant.firstName.isEmpty
                    ? 'Non renseigne'
                    : tenant.firstName,
              ),
              _InfoRow(label: 'Nom complet', value: tenant.name),
              _InfoRow(label: 'Numero de chambre', value: tenant.roomNumber),
              _InfoRow(label: 'Bien', value: tenant.propertyName),
              _InfoRow(label: 'Loyer', value: tenant.rentAmount),
              _InfoRow(label: 'Telephone', value: tenant.phone),
              _InfoRow(label: 'Email', value: tenant.email),
            ],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Dossier',
            children: [
              _DocumentRow(
                icon: Icons.description_outlined,
                title: tenant.contract.title.isEmpty
                    ? 'Contrat ${tenant.roomNumber}'
                    : tenant.contract.title,
                reference: tenant.contract.reference,
                state: tenant.contract.state,
                dateLabel: tenant.contract.dateLabel,
              ),
              _DocumentRow(
                icon: Icons.fact_check_outlined,
                title: tenant.inventory.title.isEmpty
                    ? 'Etat des lieux ${tenant.roomNumber}'
                    : tenant.inventory.title,
                reference: tenant.inventory.reference,
                state: tenant.inventory.state,
                dateLabel: tenant.inventory.dateLabel,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Suivi',
            children: [
              _InfoRow(label: 'Statut', value: tenant.statusLabel),
              _InfoRow(label: 'Solde', value: tenant.balanceLabel),
              _InfoRow(label: 'Occupation', value: tenant.occupationLabel),
              _InfoRow(label: 'Paiement', value: tenant.paymentSummary),
              _InfoRow(label: 'Urgence', value: tenant.emergencyContact),
              _InfoRow(label: 'Notes', value: tenant.notes),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final TenantRecord tenant;

  const _DetailHeader({required this.tenant});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2B5E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: tenant.statusColor,
            child: Text(
              tenant.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenant.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chambre ${tenant.roomNumber} - ${tenant.rentAmount}',
                  style: const TextStyle(color: Color(0xFFFDF6DC)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECE6D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1A2B5E),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty ? 'Non renseigne' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7A6F52),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              display,
              style: const TextStyle(
                color: Color(0xFF1A2B5E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String reference;
  final String state;
  final String dateLabel;

  const _DocumentRow({
    required this.icon,
    required this.title,
    required this.reference,
    required this.state,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final details = [
      if (reference.trim().isNotEmpty) reference,
      if (dateLabel.trim().isNotEmpty) dateLabel,
    ].join(' - ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6DC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1A2B5E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1A2B5E),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    details,
                    style: const TextStyle(
                      color: Color(0xFF7A6F52),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              state.trim().isEmpty ? 'A suivre' : state,
              style: const TextStyle(
                color: Color(0xFF1A2B5E),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      selectedItemColor: const Color(0xFF1A2B5E),
      unselectedItemColor: const Color(0xFF7A6F52),
      backgroundColor: Colors.white,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.business_outlined),
          label: 'Biens',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.payments_outlined),
          label: 'Paiement',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          label: 'Locataires',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profil',
        ),
      ],
    );
  }
}

Color? _colorFromValue(dynamic value) {
  if (value is int) return Color(value);
  if (value is String) {
    final cleaned = value.replaceFirst('#', '').replaceFirst('0x', '');
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed != null) {
      return Color(cleaned.length <= 6 ? 0xFF000000 | parsed : parsed);
    }
  }
  return null;
}

Color _statusColorFor(String status) {
  switch (status) {
    case 'Retard':
      return const Color(0xFF993C1D);
    case 'Paiement attendu':
      return const Color(0xFF854F0B);
    default:
      return const Color(0xFF3B6D11);
  }
}
