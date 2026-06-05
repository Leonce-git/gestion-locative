import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class _C {
  static const navy = Color(0xFF1A2B5E);
  static const cream = Color(0xFFF2C94C);
  static const creamLight = Color(0xFFFDF6DC);
  static const bgPage = Color(0xFFF5F0E8);
  static const white = Color(0xFFFFFFFF);
  static const textMain = Color(0xFF1A2B5E);
  static const textMuted = Color(0xFF7A6F52);
  static const border = Color(0xFFECE6D6);
  static const paidText = Color(0xFF3B6D11);
  static const freeText = Color(0xFF1A2B5E);
}

enum _PropertyFilter { all, rented, free }

class _Property {
  final String? id;
  final String title;
  final String location;
  final String type;
  final String price;
  final int priceNumber;
  final String image;
  final bool isRented;
  final String? tenantName;

  const _Property({
    this.id,
    required this.title,
    required this.location,
    required this.type,
    required this.price,
    required this.priceNumber,
    required this.image,
    required this.isRented,
    this.tenantName,
  });

  factory _Property.fromMap(Map<String, dynamic> map) {
    final status = map['status']?.toString() ?? '';
    final priceNumber = map['priceNumber'] is num
        ? (map['priceNumber'] as num).toInt()
        : _parseAmount(map['price']?.toString() ?? '');
    return _Property(
      id: map['id']?.toString(),
      title: map['title']?.toString() ?? 'Bien sans nom',
      location: map['location']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      price: map['price']?.toString() ?? '$priceNumber FCFA',
      priceNumber: priceNumber,
      image: map['image']?.toString() ?? 'assets/images/img.jpeg',
      isRented: map['isRented'] == true || status.toLowerCase().contains('lou'),
      tenantName: map['tenantName']?.toString(),
    );
  }
}

const _properties = [
  _Property(
    title: 'Maison Calavi',
    location: 'Calavi',
    type: 'Chambre A',
    price: '70 000 FCFA',
    priceNumber: 70000,
    image: 'assets/images/img.jpeg',
    isRented: true,
    tenantName: 'Ama Mensah',
  ),
  _Property(
    title: 'Appartement Plateau',
    location: 'Plateau',
    type: 'Studio meuble',
    price: '80 000 FCFA',
    priceNumber: 80000,
    image: 'assets/images/img (2).jpg',
    isRented: false,
  ),
  _Property(
    title: 'Studio Cadjehoun',
    location: 'Cadjehoun',
    type: 'Studio',
    price: '150 000 FCFA',
    priceNumber: 150000,
    image: 'assets/images/image1 (2).jpg',
    isRented: true,
    tenantName: 'Seraphine Bah',
  ),
  _Property(
    title: 'Villa Akpakpa',
    location: 'Akpakpa',
    type: 'Maison complete',
    price: '250 000 FCFA',
    priceNumber: 250000,
    image: 'assets/images/img.jpeg',
    isRented: false,
  ),
];

class MesBiens extends StatefulWidget {
  final bool showBottomNav;

  const MesBiens({super.key, this.showBottomNav = true});

  @override
  State<MesBiens> createState() => _MesBiensState();
}

class _MesBiensState extends State<MesBiens> {
  _PropertyFilter _filter = _PropertyFilter.all;
  final List<_Property> _localProperties = List.of(_properties);
  String _query = '';

  List<_Property> _filterProperties(List<_Property> properties) {
    return properties.where((property) {
      final matchesFilter = switch (_filter) {
        _PropertyFilter.all => true,
        _PropertyFilter.rented => property.isRented,
        _PropertyFilter.free => !property.isRented,
      };
      final q = _query.trim().toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          property.title.toLowerCase().contains(q) ||
          property.location.toLowerCase().contains(q) ||
          property.type.toLowerCase().contains(q) ||
          (property.tenantName ?? '').toLowerCase().contains(q);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgPage,
      appBar: AppBar(
        backgroundColor: _C.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mes biens',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Ajouter un bien',
            icon: const Icon(Icons.add_home_work_outlined),
            onPressed: _addProperty,
          ),
        ],
      ),
      body: SafeArea(child: _buildContent()),
      bottomNavigationBar: widget.showBottomNav
          ? _buildBottomNav(context)
          : null,
    );
  }

  Widget _buildContent() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final demoTotal = _localProperties.fold<int>(
        0,
        (sum, p) => sum + p.priceNumber,
      );
      return _propertiesContent(_localProperties, 9, demoTotal);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('biens')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('locataires')
              .snapshots(),
          builder: (context, tenantSnapshot) {
            final properties = snapshot.hasData
                ? snapshot.data!.docs
                      .map(
                        (doc) => _Property.fromMap({
                          ...(doc.data() as Map<String, dynamic>),
                          'id': doc.id,
                        }),
                      )
                      .toList()
                : <_Property>[];
            final tenantDocs = tenantSnapshot.data?.docs ?? [];
            final monthlyRentTotal = tenantDocs.fold<int>(0, (sum, doc) {
              final map = doc.data() as Map<String, dynamic>;
              return sum + _parseAmount(map['rentAmount']?.toString() ?? '');
            });
            final propertyRentTotal = properties.fold<int>(
              0,
              (sum, p) => sum + p.priceNumber,
            );
            return _propertiesContent(
              properties,
              tenantDocs.length,
              monthlyRentTotal == 0 ? propertyRentTotal : monthlyRentTotal,
            );
          },
        );
      },
    );
  }

 // ✅ CORRIGÉ
Future<void> _addProperty() async {
  await Navigator.pushNamed(context, '/ajout');
  // Rien à faire : le StreamBuilder se met à jour automatiquement
  // grâce à Firestore en temps réel
}

  Widget _propertiesContent(
    List<_Property> properties,
    int tenantCount,
    int monthlyRentTotal,
  ) {
    final filtered = _filterProperties(properties);

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: _C.navy,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Row(
            children: [
              Expanded(
                child: _StatBox(value: '${properties.length}', label: 'Biens'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(value: '$tenantCount', label: 'Locataires'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  value: _formatAmount(monthlyRentTotal),
                  label: 'FCFA/mois',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            style: const TextStyle(color: _C.textMain),
            decoration: InputDecoration(
              hintText: 'Rechercher un bien',
              hintStyle: const TextStyle(color: _C.textMuted),
              prefixIcon: const Icon(Icons.search, color: _C.textMuted),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _FilterButton(
                  label: 'Tous',
                  count: properties.length,
                  selected: _filter == _PropertyFilter.all,
                  onTap: () => setState(() => _filter = _PropertyFilter.all),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterButton(
                  label: 'Loues',
                  count: properties.where((p) => p.isRented).length,
                  selected: _filter == _PropertyFilter.rented,
                  onTap: () => setState(() => _filter = _PropertyFilter.rented),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterButton(
                  label: 'Libres',
                  count: properties.where((p) => !p.isRented).length,
                  selected: _filter == _PropertyFilter.free,
                  onTap: () => setState(() => _filter = _PropertyFilter.free),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun bien trouve.',
                    style: TextStyle(color: _C.textMuted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _PropertyCard(property: filtered[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 1,
      selectedItemColor: _C.navy,
      unselectedItemColor: _C.textMuted,
      backgroundColor: Colors.white,
      onTap: (i) {
        final routes = [
          '/accueil',
          '/mesBiens',
          '/paiement',
          '/locataire',
          '/profil',
        ];
        if (i == 1) return;
        Navigator.pushReplacementNamed(context, routes[i]);
      },
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
          label: 'Paiements',
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

class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _C.creamLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _C.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: _C.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _C.cream : _C.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _C.cream : _C.border),
        ),
        child: Center(
          child: Text(
            '$label ($count)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? _C.navy : _C.textMuted,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class PropertyCard extends StatelessWidget {
  final _Property property;
  final VoidCallback? onDelete;

  const PropertyCard({required this.property, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final statusColor = property.isRented ? _C.paidText : _C.freeText;
    final statusBg = property.isRented
        ? const Color(0xFFF0FAE4)
        : _C.creamLight;

    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: Image.asset(
              property.image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: _C.creamLight,
                child: const Icon(Icons.home_work_outlined, color: _C.navy),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.textMain,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          property.isRented ? 'Loué' : 'Libre',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${property.type} - ${property.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _C.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    property.price,
                    style: const TextStyle(
                      color: _C.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    property.isRented
                        ? 'Locataire : ${property.tenantName ?? 'Non renseigné'}'
                        : 'Disponible maintenant',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _C.textMuted, fontSize: 12),
                  ),
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    // Bouton Modifier
    IconButton(
  tooltip: 'Modifier',
  icon: const Icon(Icons.edit, color: Colors.blue),
  onPressed: () {
    Navigator.pushNamed(
      context,
      '/editMaison',
      arguments: {
        'id': property.id,
        'title': property.title,
        'priceNumber': property.priceNumber,
        'location': property.location,
        'description': '', // ajoute si tu stockes une description
      },
    );
  },
),

    // Bouton Supprimer
    IconButton(
      tooltip: 'Supprimer',
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && property.id != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('biens')
              .doc(property.id)
              .delete();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bien supprimé avec succès')),
          );
        }
      },
    ),
  ],
),
                    
                      
                    
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final _Property property;
  final VoidCallback? onDelete;

  const _PropertyCard({required this.property, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PropertyCard(property: property, onDelete: onDelete);
  }
}

int _parseAmount(String value) {
  return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}

String _formatAmount(int value) {
  final s = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(s[i]);
  }
  return buffer.toString();
}
