import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gestion_locative/app_background.dart';

class _C {
  static const navy = Color(0xFF1A2B5E);
  static const creamLight = Color(0xFFFDF6DC);
  static const white = Color(0xFFFFFFFF);
  static const textMain = Color(0xFF1A2B5E);
  static const textMuted = Color(0xFF7A6F52);
  static const border = Color(0xFFECE6D6);
  static const success = Color(0xFF3B6D11);
  static const warning = Color(0xFF854F0B);
  static const danger = Color(0xFF993C1D);
}

class AjoutMaison extends StatefulWidget {
  const AjoutMaison({super.key});

  @override
  State<AjoutMaison> createState() => _AjoutMaisonState();
}

class _AjoutMaisonState extends State<AjoutMaison> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();
  final _descController = TextEditingController();
  final _roomsController = TextEditingController();

  String _selectedEtat = 'Disponible';
  String _selectedType = 'Maison';
  bool _isSaving = false;

  Uint8List? _selectedImageBytes;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 25);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() => _selectedImageBytes = bytes);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _descController.dispose();
    _roomsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSaveError('Vous devez être connecté pour ajouter un bien.');
      setState(() => _isSaving = false);
      return;
    }

    String imageBase64 = '';
    if (_selectedImageBytes != null) {
      imageBase64 = base64Encode(_selectedImageBytes!);
    }

    final price =
        int.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    final propertyData = {
      'title': _titleController.text.trim(),
      'location': _addressController.text.trim(),
      'type': _selectedType,
      'price': '${_priceController.text.trim()} FCFA',
      'priceNumber': price,
      'rooms': _roomsController.text.trim(),
      'description': _descController.text.trim(),
      'status': _selectedEtat,
      'isRented': _selectedEtat.toLowerCase().contains('lou'),
      'image': imageBase64,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('biens')
          .add(propertyData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_titleController.text.trim()} ajouté avec succès !'),
          backgroundColor: _C.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, propertyData);
    } on FirebaseException catch (e) {
      if (mounted) _showSaveError(e.message ?? 'Enregistrement impossible.');
    } catch (e) {
      if (mounted) _showSaveError('Erreur: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSaveError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _C.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.navy,
      appBar: AppBar(
        backgroundColor: _C.navy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ajouter un bien', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Nouveau bien immobilier', style: TextStyle(fontSize: 12, color: Color(0xFFD0D8F0))),
          ],
        ),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: _C.navy, borderRadius: BorderRadius.circular(18)),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nouveau bien immobilier', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                        SizedBox(height: 8),
                        Text('Renseignez les informations du bien pour le suivre dans votre tableau de bord.', style: TextStyle(color: Color(0xFFFDF6DC), height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    icon: Icons.home_work_outlined, iconColor: _C.navy, title: 'Type de bien',
                    child: _TypeSelector(selected: _selectedType, onChanged: (v) => setState(() => _selectedType = v)),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    icon: Icons.edit_outlined, iconColor: _C.navy, title: 'Informations principales',
                    child: Column(children: [
                      _Field(controller: _titleController, label: 'Nom du bien', hint: 'Ex : Villa Les Cocotiers', icon: Icons.home_outlined, validator: _required),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _Field(controller: _priceController, label: 'Loyer (FCFA)', hint: '150 000', icon: Icons.payments_outlined, keyboardType: TextInputType.number, validator: _required)),
                        const SizedBox(width: 12),
                        Expanded(child: _Field(controller: _roomsController, label: 'Chambres', hint: 'Ex : 4', icon: Icons.meeting_room_outlined, keyboardType: TextInputType.number)),
                      ]),
                      const SizedBox(height: 12),
                      _Field(controller: _addressController, label: 'Adresse', hint: 'Quartier, Ville', icon: Icons.location_on_outlined, validator: _required),
                      const SizedBox(height: 12),
                      _Field(controller: _descController, label: 'Description', hint: 'Eau courante, compteur, acces...', icon: Icons.notes_rounded, maxLines: 3),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    icon: Icons.toggle_on_outlined, iconColor: _C.success, title: 'Etat du bien',
                    child: _EtatSelector(selected: _selectedEtat, onChanged: (v) => setState(() => _selectedEtat = v)),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    icon: Icons.image_outlined, iconColor: _C.navy, title: 'Image du bien',
                    child: Column(children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(onPressed: () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library), label: const Text("Galerie")),
                          if (!kIsWeb) ElevatedButton.icon(onPressed: () => _pickImage(ImageSource.camera), icon: const Icon(Icons.camera_alt), label: const Text("Caméra")),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_selectedImageBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_selectedImageBytes!, height: 180, width: double.infinity, fit: BoxFit.cover),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.navy,
                        disabledBackgroundColor: _C.navy.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                        shadowColor: _C.navy.withValues(alpha: 0.22),
                      ),
                      child: _SaveButtonContent(isSaving: _isSaving),
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

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Ce champ est obligatoire' : null;
}

class _SaveButtonContent extends StatelessWidget {
  final bool isSaving;
  const _SaveButtonContent({required this.isSaving});

  @override
  Widget build(BuildContext context) {
    if (isSaving) {
      return const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
        SizedBox(width: 10),
        Text('Enregistrement...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
      ]);
    }
    return const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.add_home_outlined, color: Colors.white, size: 20),
      SizedBox(width: 10),
      Text('Enregistrer le bien', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
    ]);
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  const _SectionCard({required this.icon, required this.iconColor, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 18)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: _C.textMain, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  const _Field({required this.controller, required this.label, required this.hint, required this.icon, this.keyboardType, this.maxLines = 1, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller, keyboardType: keyboardType, maxLines: maxLines, validator: validator,
      style: const TextStyle(color: _C.textMain, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(color: _C.textMuted, fontSize: 13),
        hintStyle: TextStyle(color: _C.textMuted.withValues(alpha: 0.55), fontSize: 13),
        prefixIcon: Icon(icon, color: _C.textMuted, size: 20),
        filled: true, fillColor: _C.creamLight, alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _C.border, width: 1.4)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _C.navy, width: 1.8)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _C.danger, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _C.danger, width: 1.8)),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _TypeSelector({required this.selected, required this.onChanged});

  static const _types = [
    _TypeOption('Maison', Icons.home_outlined),
    _TypeOption('Villa', Icons.villa_outlined),
    _TypeOption('Appartement', Icons.apartment_outlined),
    _TypeOption('Chambre', Icons.meeting_room_outlined),
    _TypeOption('Bureau', Icons.business_outlined),
    _TypeOption('Studio', Icons.bed_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _types.map((type) {
        final isSelected = selected == type.label;
        return GestureDetector(
          onTap: () => onChanged(type.label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: isSelected ? _C.navy : _C.creamLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: isSelected ? _C.navy : _C.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(type.icon, size: 15, color: isSelected ? Colors.white : _C.textMuted),
              const SizedBox(width: 6),
              Text(type.label, style: TextStyle(color: isSelected ? Colors.white : _C.textMain, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _TypeOption {
  final String label;
  final IconData icon;
  const _TypeOption(this.label, this.icon);
}

class _EtatSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _EtatSelector({required this.selected, required this.onChanged});

  static const _states = [
    _EtatOption('Disponible', _C.success, Icons.check_circle_outline_rounded),
    _EtatOption('Loue', _C.navy, Icons.people_outline_rounded),
    _EtatOption('En travaux', _C.warning, Icons.construction_outlined),
    _EtatOption('Indisponible', _C.danger, Icons.block_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _states.map((state) {
        final isSelected = selected == state.label;
        return GestureDetector(
          onTap: () => onChanged(state.label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? state.color.withValues(alpha: 0.08) : _C.creamLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isSelected ? state.color : _C.border, width: isSelected ? 1.8 : 1.2),
            ),
            child: Row(children: [
              Icon(state.icon, color: isSelected ? state.color : _C.textMuted, size: 18),
              const SizedBox(width: 12),
              Text(state.label, style: TextStyle(color: isSelected ? state.color : _C.textMain, fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              if (isSelected) Icon(Icons.check_rounded, color: state.color, size: 18),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _EtatOption {
  final String label;
  final Color color;
  final IconData icon;
  const _EtatOption(this.label, this.color, this.icon);
}
