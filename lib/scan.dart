import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gestion_locative/app_background.dart';

class Scan extends StatefulWidget {
  const Scan({super.key});

  @override
  State<Scan> createState() => _ScanState();
}

class _ScanState extends State<Scan> with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;

  File? _scannedImage;           // mobile
  Uint8List? _scannedImageBytes; // web

  bool _isScanning = false;
  bool _scanFailed = false;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  bool get _hasScan =>
      kIsWeb ? _scannedImageBytes != null : _scannedImage != null;

  // Remplace DocumentScannerFlutter par image_picker (caméra)
  Future<void> _scanDocument() async {
    setState(() {
      _isScanning = true;
      _scanError = null;
      _scanFailed = false;
    });

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (pickedFile == null || !mounted) return;

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() => _scannedImageBytes = bytes);
      } else {
        setState(() => _scannedImage = File(pickedFile.path));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scanError = 'Caméra indisponible. Vous pouvez importer un fichier.';
        _scanFailed = true;
      });
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _pickFile() async {
    setState(() => _scanError = null);

    try {
      if (kIsWeb) {
        // Sur web : utiliser image_picker galerie
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (pickedFile == null || !mounted) return;
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _scannedImageBytes = bytes;
          _scanFailed = false;
          _scanError = null;
        });
      } else {
        // Sur mobile : file_picker pour images et PDF
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        );
        if (result == null || result.files.single.path == null || !mounted) {
          return;
        }
        setState(() {
          _scannedImage = File(result.files.single.path!);
          _scanFailed = false;
          _scanError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanError = 'Impossible d\'ouvrir le fichier: $e');
    }
  }

  void _validateScan() {
    if (!_hasScan) return;
    final label = kIsWeb
        ? 'Document scanné (web)'
        : 'Document scanné: ${_scannedImage!.path}';
    Navigator.pop(context, label);
  }

  void _resetScan() {
    setState(() {
      _scannedImage = null;
      _scannedImageBytes = null;
      _scanError = null;
      _scanFailed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Scanner un dossier',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ScanHero(),
                    const SizedBox(height: 18),
                    Center(
                      child: _ScanFrame(
                        animation: _scanController,
                        image: _scannedImage,
                        imageBytes: _scannedImageBytes,
                        isScanning: _isScanning,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ScanActionPanel(
                      hasScan: _hasScan,
                      isScanning: _isScanning,
                      scanFailed: _scanFailed,
                      onScan: _scanDocument,
                      onValidate: _validateScan,
                      onReset: _resetScan,
                      onPickFile: _pickFile,
                    ),
                    const SizedBox(height: 16),
                    if (_scanError != null)
                      _ScanStatusCard(
                        icon: Icons.error_outline,
                        title: 'Scan interrompu',
                        message: _scanError!,
                        color: const Color(0xFFD64545),
                      )
                    else if (_hasScan)
                      _ScanStatusCard(
                        icon: Icons.check_circle_outline,
                        title: 'Document capturé',
                        message:
                            'Vérifiez l\'aperçu, puis validez pour l\'ajouter au dossier.',
                        color: const Color(0xFF149954),
                      )
                    else
                      const _ScanHelpBubble(),
                    const SizedBox(height: 16),
                    _ScanTips(hasScan: _hasScan),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanHero extends StatelessWidget {
  const _ScanHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102A43), Color(0xFF1F6FEB), Color(0xFF63B3ED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        children: [
          _HeroIcon(),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Numériser un document',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Cadrez le contrat, l\'état des lieux ou une pièce du dossier locataire.',
                  style: TextStyle(color: Color(0xFFDDEAF8), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.document_scanner_outlined,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  final Animation<double> animation;
  final File? image;
  final Uint8List? imageBytes;
  final bool isScanning;

  const _ScanFrame({
    required this.animation,
    required this.image,
    required this.imageBytes,
    required this.isScanning,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = kIsWeb ? imageBytes != null : image != null;

    return AspectRatio(
      aspectRatio: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF132238),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF132238).withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: !hasImage
                    ? const _EmptyScanSurface()
                    : kIsWeb
                        ? Image.memory(imageBytes!, fit: BoxFit.cover)
                        : Image.file(image!, fit: BoxFit.cover),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: hasImage ? 0.08 : 0,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScannerCornerPainter(
                    color: hasImage
                        ? const Color(0xFF149954)
                        : const Color(0xFF63B3ED),
                  ),
                ),
              ),
              if (!hasImage)
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Positioned(
                      left: 28,
                      right: 28,
                      top: 28 + (244 * animation.value),
                      child: child!,
                    );
                  },
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF63B3ED), Color(0xFFFFFFFF)],
                      ),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF63B3ED).withValues(alpha: 0.55),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              if (isScanning)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyScanSurface extends StatelessWidget {
  const _EmptyScanSurface();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF132238), Color(0xFF24496F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, color: Color(0xFFDDEAF8), size: 52),
            SizedBox(height: 10),
            Text(
              'Placez le document dans le cadre',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFDDEAF8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerCornerPainter extends CustomPainter {
  final Color color;

  const _ScannerCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const cornerLength = 58.0;
    const inset = 16.0;

    canvas.drawLine(const Offset(inset, inset), const Offset(inset + cornerLength, inset), paint);
    canvas.drawLine(const Offset(inset, inset), const Offset(inset, inset + cornerLength), paint);
    canvas.drawLine(Offset(size.width - inset, inset), Offset(size.width - inset - cornerLength, inset), paint);
    canvas.drawLine(Offset(size.width - inset, inset), Offset(size.width - inset, inset + cornerLength), paint);
    canvas.drawLine(Offset(inset, size.height - inset), Offset(inset + cornerLength, size.height - inset), paint);
    canvas.drawLine(Offset(inset, size.height - inset), Offset(inset, size.height - inset - cornerLength), paint);
    canvas.drawLine(Offset(size.width - inset, size.height - inset), Offset(size.width - inset - cornerLength, size.height - inset), paint);
    canvas.drawLine(Offset(size.width - inset, size.height - inset), Offset(size.width - inset, size.height - inset - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerCornerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ScanActionPanel extends StatelessWidget {
  final bool hasScan;
  final bool isScanning;
  final bool scanFailed;
  final VoidCallback onScan;
  final VoidCallback onValidate;
  final VoidCallback onReset;
  final VoidCallback onPickFile;

  const _ScanActionPanel({
    required this.hasScan,
    required this.isScanning,
    required this.scanFailed,
    required this.onScan,
    required this.onValidate,
    required this.onReset,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isScanning ? null : onScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF132238),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFF132238).withValues(alpha: 0.45),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: Icon(
                hasScan
                    ? Icons.document_scanner_outlined
                    : Icons.camera_alt_outlined,
              ),
              label: Text(
                isScanning
                    ? 'Ouverture de la caméra...'
                    : hasScan
                        ? 'Reprendre le scan'
                        : 'Lancer le scan',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPickFile,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2B7FFF),
                side: const BorderSide(color: Color(0xFF2B7FFF)),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text(
                'Importer depuis l\'appareil',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (hasScan) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isScanning ? null : onReset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF132238),
                      side: const BorderSide(color: Color(0xFFD4DFEA)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Effacer'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isScanning ? null : onValidate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF149954),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Valider'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ScanHelpBubble extends StatelessWidget {
  const _ScanHelpBubble();

  @override
  Widget build(BuildContext context) {
    return _ScanStatusCard(
      icon: Icons.tips_and_updates_outlined,
      title: 'Conseil de scan',
      message:
          'Posez le document à plat, gardez les bords visibles et évitez les ombres pour obtenir une image nette.',
      color: const Color(0xFF2B7FFF),
    );
  }
}

class _ScanStatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _ScanStatusCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF132238),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style:
                      const TextStyle(color: Color(0xFF526072), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanTips extends StatelessWidget {
  final bool hasScan;

  const _ScanTips({required this.hasScan});

  @override
  Widget build(BuildContext context) {
    final items = hasScan
        ? const [
            _TipItem(
              icon: Icons.visibility_outlined,
              label: 'Aperçu vérifié',
              color: Color(0xFF2B7FFF),
            ),
            _TipItem(
              icon: Icons.folder_open_outlined,
              label: 'Prêt pour le dossier',
              color: Color(0xFFF39C12),
            ),
          ]
        : const [
            _TipItem(
              icon: Icons.light_mode_outlined,
              label: 'Bonne lumière',
              color: Color(0xFFF39C12),
            ),
            _TipItem(
              icon: Icons.crop_free_outlined,
              label: 'Bords visibles',
              color: Color(0xFF2B7FFF),
            ),
            _TipItem(
              icon: Icons.back_hand_outlined,
              label: 'Image stable',
              color: Color(0xFF149954),
            ),
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contrôle rapide',
            style: TextStyle(
              color: Color(0xFF132238),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: items),
        ],
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TipItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF132238),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
