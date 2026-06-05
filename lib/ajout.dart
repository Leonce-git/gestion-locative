import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gestion_locative/app_background.dart';
import 'package:gestion_locative/locataire.dart';
import 'package:gestion_locative/payment_code_service.dart';
import 'package:gestion_locative/scan.dart';

class _Property {
  final String? id;
  final String title;
  final String type;
  final String location;
  final int priceNumber;

  _Property({
    this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.priceNumber,
  });

  factory _Property.fromMap(Map<String, dynamic> map) {
    return _Property(
      id: map['id'],
      title: map['title'] ?? '',
      type: map['type'] ?? '',
      location: map['location'] ?? '',
      priceNumber: map['priceNumber'] ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Property && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class _C {
  static const navy = Color(0xFF1A2B5E);
  static const cream = Color(0xFFF2C94C);
  static const creamLight = Color(0xFFFDF6DC);
  static const bgPage = Color(0xFFF5F0E8);
  static const white = Color(0xFFFFFFFF);
  static const textMain = Color(0xFF1A2B5E);
  static const textMuted = Color(0xFF7A6F52);
  static const border = Color(0xFFECE6D6);
  static const success = Color(0xFF3B6D11);
  static const warning = Color(0xFF854F0B);
  static const danger = Color(0xFF993C1D);
}

class Ajout extends StatefulWidget {
  const Ajout({super.key});

  @override
  State<Ajout> createState() => _AjoutState();
}

class _AjoutState extends State<Ajout> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roomController = TextEditingController();
  final _propertyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _rentController = TextEditingController();
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();

  _Property? selectedProperty;

  String _selectedStatus = 'A jour';
  String? _scannedFolderLabel;
  String? tenantId;

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _propertyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _rentController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Étape 2 : Scanner un document ──
  Future<void> _scanDocument(String type) async {
    final downloadUrl = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const Scan()),
    );

    if (downloadUrl != null && tenantId != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('locataires')
          .doc(tenantId)
          .collection('documents')
          .add({
        'type': type,
        'url': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Document $type scanné et ajouté au dossier !')),
      );
    }
  } // ← accolade fermante de _scanDocument (était manquante)

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final room = _roomController.text.trim().toUpperCase();
    final property = _propertyController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final rent = _rentController.text.trim();
    final emergencyContact = _contactController.text.trim();
    final notes = _notesController.text.trim();
    final dateLabel = _todayLabel();

    final tenantData = {
      'name': name,
      'nom': name,
      'roomNumber': room,
      'chambre': room,
      'propertyName': property,
      'bien': property,
      'phone': phone,
      'email': email,
      'rentAmount': '$rent FCFA',
      'statusLabel': _selectedStatus,
      'balanceLabel': _statusMetaFor(_selectedStatus),
      'occupationLabel': 'Ajouté le $dateLabel',
      'contract': {
        'title': 'Contrat $room',
        'reference': 'CTR-$room-${DateTime.now().year}',
        'dateLabel': 'Créé le $dateLabel',
        'state': 'Nouveau',
      },
      'inventory': {
        'title': 'État des lieux $room',
        'reference': 'EDL-$room-${DateTime.now().year}',
        'dateLabel': 'À programmer',
        'state': 'À faire',
      },
      'paymentSummary': 'Dossier créé, première échéance à planifier',
      'notes': notes.isEmpty ? 'Aucune note ajoutée pour le moment.' : notes,
      'emergencyContact': emergencyContact.isEmpty
          ? 'Contact urgence non renseigné'
          : 'Contact urgence : $emergencyContact',
    };

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('locataires')
            .add({...tenantData, 'createdAt': FieldValue.serverTimestamp()});

        // Génère et enregistre le code de paiement unique (depuis origin/main)
        await PaymentCodeService.createForTenant(
          uid: user.uid,
          tenantId: docRef.id,
          tenantName: name,
        );

        // ➜ Sauvegarder l'ID pour rattacher les documents
        tenantId = docRef.id;

        // ➜ Mettre à jour le bien choisi comme "Loué"
        if (selectedProperty?.id != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('biens')
              .doc(selectedProperty!.id)
              .update({
            'isRented': true,
            'tenantName': name,
          });
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name ajouté avec succès !'),
            backgroundColor: _C.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        final tenantRecord = TenantRecord(
          name: name,
          roomNumber: room,
          propertyName: property,
          phone: phone,
          email: email,
          rentAmount: '$rent FCFA',
          statusLabel: _selectedStatus,
          statusColor: _statusColorFor(_selectedStatus),
          balanceLabel: _statusMetaFor(_selectedStatus),
          occupationLabel: 'Ajouté le $dateLabel',
          contract: TenantDocument(
            title: 'Contrat $room',
            reference: 'CTR-$room-${DateTime.now().year}',
            dateLabel: 'Créé le $dateLabel',
            state: 'Nouveau',
          ),
          inventory: TenantDocument(
            title: 'État des lieux $room',
            reference: 'EDL-$room-${DateTime.now().year}',
            dateLabel: 'À programmer',
            state: 'À faire',
          ),
          paymentSummary: 'Dossier créé, première échéance à planifier',
          notes: notes.isEmpty ? 'Aucune note ajoutée pour le moment.' : notes,
          emergencyContact: emergencyContact.isEmpty
              ? 'Contact urgence non renseigné'
              : 'Contact urgence : $emergencyContact',
        );

        if (mounted) Navigator.of(context).pop(tenantRecord);
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.message ?? "Enregistrement impossible"}'),
          backgroundColor: _C.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enregistrement impossible pour le moment.'),
          backgroundColor: _C.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _scanFolder() async {
    final label = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const Scan()));

    if (label == null || !mounted) return;

    setState(() => _scannedFolderLabel = label);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Scan du dossier terminé.'),
        backgroundColor: _C.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgPage,
      appBar: AppBar(
        backgroundColor: _C.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF132238).withValues(alpha: 0.06),
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
              'Ajouter un locataire',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF132238),
              ),
            ),
            SizedBox(height: 4), // ← doublon supprimé
            Text(
              'Nouveau dossier',
              style: TextStyle(fontSize: 12, color: Color(0xFF607086)),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: _scanFolder,
            child: Container(
              margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF132238),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.document_scanner_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Scanner',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          'Nouveau dossier locataire',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Renseignez les informations pour ajouter le locataire à votre liste de suivi.',
                          style: TextStyle(
                            color: Color(0xFFDDEAF8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Section 1 : Informations principales ──
                  _SectionCard(
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFF1F6FEB),
                    title: 'Informations principales',
                    child: Column(
                      children: [
                        _Field(
                          controller: _nameController,
                          label: 'Nom complet',
                          icon: Icons.badge_outlined,
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: 12),

                        // Champ Bien loué avec liste des biens disponibles
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .collection('biens')
                              .where('isRented', isEqualTo: false)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }

                            final availableProperties = snapshot.data!.docs
                                .map((doc) => _Property.fromMap({
                                      ...(doc.data() as Map<String, dynamic>),
                                      'id': doc.id,
                                    }))
                                .toList();

                            return DropdownButtonFormField<_Property>(
                              value: selectedProperty,
                              items: availableProperties.map((p) {
                                return DropdownMenuItem(
                                  value: p,
                                  child: Text('${p.title} - ${p.location}'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedProperty = value;
                                  _propertyController.text = value!.title;
                                  _roomController.text = value.type;
                                  _rentController.text =
                                      value.priceNumber.toString();
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: 'Bien loué',
                                prefixIcon:
                                    Icon(Icons.home_work_outlined),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),
                        _Field(
                          controller: _rentController,
                          label: 'Loyer (FCFA)',
                          icon: Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _roomController,
                          label: 'Chambre',
                          icon: Icons.meeting_room_outlined,
                          validator: _requiredValidator,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Section 2 : Coordonnées ──
                  _SectionCard(
                    icon: Icons.contact_phone_outlined,
                    iconColor: const Color(0xFF149954),
                    title: 'Coordonnées',
                    child: Column(
                      children: [
                        _Field(
                          controller: _phoneController,
                          label: 'Téléphone',
                          icon: Icons.call_outlined,
                          keyboardType: TextInputType.phone,
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: _emailValidator,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _contactController,
                          label: 'Contact urgence',
                          icon: Icons.support_agent_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Section 3 : Suivi du dossier ──
                  _SectionCard(
                    icon: Icons.track_changes_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Suivi du dossier',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Statut initial',
                          style: TextStyle(
                            color: Color(0xFF607086),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StatusSelector(
                          selected: _selectedStatus,
                          onChanged: (v) => setState(() => _selectedStatus = v),
                        ),
                        const SizedBox(height: 16),

                        // Zone scan dossier
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FA),
                            borderRadius: BorderRadius.circular(18),
                            border:
                                Border.all(color: const Color(0xFFDDEAF8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF132238,
                                      ).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.folder_open_outlined,
                                      color: Color(0xFF132238),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Dossier locataire',
                                      style: TextStyle(
                                        color: Color(0xFF132238),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _scanFolder,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF132238),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.document_scanner_outlined,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            'Scanner',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    _scannedFolderLabel != null
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.info_outline_rounded,
                                    size: 14,
                                    color: _scannedFolderLabel != null
                                        ? const Color(0xFF149954)
                                        : const Color(0xFF7D8CA0),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _scannedFolderLabel ??
                                          'Aucun scan effectué',
                                      style: TextStyle(
                                        color: _scannedFolderLabel != null
                                            ? const Color(0xFF149954)
                                            : const Color(0xFF7D8CA0),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Notes
                        _Field(
                          controller: _notesController,
                          label: 'Notes',
                          icon: Icons.edit_note_outlined,
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Bouton valider ──
                  GestureDetector(
                    onTap: _submit,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF102A43), Color(0xFF1F6FEB)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1F6FEB).withOpacity(0.30),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add_alt_1_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Ajouter à la liste',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ce champ est obligatoire';
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ce champ est obligatoire';
    if (!value.contains('@') || !value.contains('.')) {
      return 'Veuillez saisir un email valide';
    }
    return null;
  }

  String _todayLabel() {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    final now = DateTime.now();
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Color _statusColorFor(String status) {
    switch (status) {
      case 'Retard':
        return const Color(0xFFE53935);
      case 'Paiement attendu':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF149954);
    }
  }

  String _statusMetaFor(String status) {
    switch (status) {
      case 'Retard':
        return 'Relance à programmer';
      case 'Paiement attendu':
        return 'Première échéance en attente';
      default:
        return 'Dossier créé';
    }
  }
}

// ─────────────────────────────────────────────
// SECTION CARD
// ─────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF132238).withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF132238),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CHAMP TEXTE
// ─────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(
        color: Color(0xFF132238),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF7D8CA0), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF7D8CA0), size: 20),
        filled: true,
        fillColor: const Color(0xFFF0F4FA),
        alignLabelWithHint: maxLines > 1,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDDEAF8), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1F6FEB), width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.8),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SÉLECTEUR DE STATUT (pills visuelles)
// ─────────────────────────────────────────────

class _StatusSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _StatusSelector({required this.selected, required this.onChanged});

  static const _statuses = [
    _StatusOption(
      'A jour',
      Color(0xFF149954),
      Icons.check_circle_outline_rounded,
    ),
    _StatusOption(
      'Paiement attendu',
      Color(0xFFF59E0B),
      Icons.schedule_rounded,
    ),
    _StatusOption('Retard', Color(0xFFE53935), Icons.warning_amber_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _statuses.map((s) {
        final isSelected = selected == s.label;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(s.label),
            child: Container(
              margin: EdgeInsets.only(right: s == _statuses.last ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? s.color.withOpacity(0.12)
                    : const Color(0xFFF0F4FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? s.color : const Color(0xFFDDEAF8),
                  width: isSelected ? 1.8 : 1.2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    s.icon,
                    color: isSelected ? s.color : const Color(0xFF7D8CA0),
                    size: 18,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.label == 'Paiement attendu' ? 'Attendu' : s.label,
                    style: TextStyle(
                      color: isSelected ? s.color : const Color(0xFF7D8CA0),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
class _StatusOption {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusOption(this.label, this.color, this.icon);
}
