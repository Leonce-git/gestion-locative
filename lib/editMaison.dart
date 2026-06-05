import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
class EditMaison extends StatefulWidget {
  final Map<String, dynamic> propertyData;
  final String propertyId;

  const EditMaison({super.key, required this.propertyData, required this.propertyId});

  @override
  State<EditMaison> createState() => _EditMaisonState();
}

class _EditMaisonState extends State<EditMaison> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _locationController;
  late TextEditingController _descController;

  File? _selectedImage;           // mobile
  Uint8List? _selectedImageBytes; // web

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.propertyData['title']);
    _priceController = TextEditingController(text: widget.propertyData['priceNumber'].toString());
    _locationController = TextEditingController(text: widget.propertyData['location']);
    _descController = TextEditingController(text: widget.propertyData['description']);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _descController.dispose();
    super.dispose();
  }
  // Sélection d'image (galerie ou caméra)
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() => _selectedImageBytes = bytes);
      } else {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    }
  }
  // Upload pour le web (bytes)
  Future<String?> _uploadImageBytes(Uint8List bytes, String userId) async {
    final ref = FirebaseStorage.instance.ref().child(
      'users/$userId/biens/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putData(bytes);
    return await ref.getDownloadURL();
  }

  // Upload pour mobile (File)
  Future<String?> _uploadImageFile(File image, String userId) async {
    final ref = FirebaseStorage.instance.ref().child(
      'users/$userId/biens/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> _updateProperty() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // On garde l'ancienne image si aucune nouvelle n'est choisie
    String? imageUrl = widget.propertyData['image'];

    if (kIsWeb && _selectedImageBytes != null) {
      imageUrl = await _uploadImageBytes(_selectedImageBytes!, user.uid);
    } else if (!kIsWeb && _selectedImage != null) {
      imageUrl = await _uploadImageFile(_selectedImage!, user.uid);
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('biens')
        .doc(widget.propertyId)
        .update({
      'title': _titleController.text.trim(),
      'priceNumber': int.tryParse(_priceController.text) ?? 0,
      'location': _locationController.text.trim(),
      'description': _descController.text.trim(),
      'image': imageUrl ?? '',
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bien modifié avec succès')),
    );
    Navigator.pop(context);
  }

  // Widget d'aperçu de l'image
  Widget _buildImagePreview() {
    // Nouvelle image sélectionnée sur web
    if (kIsWeb && _selectedImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _selectedImageBytes!,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    // Nouvelle image sélectionnée sur mobile
    if (!kIsWeb && _selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          _selectedImage!,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    // Ancienne image depuis Firestore
    final existingImage = widget.propertyData['image'] ?? '';
    if (existingImage.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          existingImage,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Modifier le bien")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Nom du bien"),
              validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
            ),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: "Prix"),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
            ),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: "Adresse"),
              validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
            ),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: "Description"),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Galerie"),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Caméra"),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _buildImagePreview(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateProperty,
              child: const Text("Mettre à jour"),
            ),
          ],
        ),
      ),
    );
  }
}
