import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gestion_locative/Accueil.dart';
// import 'package:gestion_locative/Dashboard.dart';
// import 'package:gestion_locative/app_background.dart';

// ─────────────────────────────────────────────
// Palette — fidèle aux maquettes Figma
// ─────────────────────────────────────────────
class AppColors {
  // Couleurs principales
  static const navy = Color(0xFF1A2B5E); // fond header, texte titre
  static const navyDark = Color(0xFF132040); // variante sombre
  static const cream = Color(0xFFF2C94C); // bouton principal, logo circle
  static const creamLight = Color(0xFFFDF6DC); // fond général, champs input
  static const creamBorder = Color(0xFFE8C84A); // bordure champs actifs

  // Texte
  static const textMain = Color(0xFF1A2B5E);
  static const textMuted = Color(0xFF7A6F52);
  static const textLight = Color(0xFFFFFFFF);

  // Card
  static const cardBg = Color(0xFFFFFFFF);
  static const inputFill = Color(0xFFFDF6DC); // même que creamLight

  // Statuts
  static const statusPaid = Color(0xFF3B6D11);
  static const statusPaidBg = Color(0xFFEAF3DE);
  static const statusLate = Color(0xFF993C1D);
  static const statusLateBg = Color(0xFFFFEBE5);
  static const statusPend = Color(0xFF854F0B);
  static const statusPendBg = Color(0xFFFAEEDA);
  static const statusFree = Color(0xFF1A2B5E);
  static const statusFreeBg = Color(0xFFF2C94C);
}

// ─────────────────────────────────────────────
// connect.dart  — Écran Connexion / Inscription
// ─────────────────────────────────────────────
class Connect extends StatefulWidget {
  const Connect({super.key});
  @override
  State<Connect> createState() => _ConnectState();
}

class _ConnectState extends State<Connect> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  bool _showLogin = true;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isSubmitting = false;

  void _goToAcceuil(String userName) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => Accueil(userName: userName)),
    );
  }

  // Rôle inscription
  String _role = 'Propriétaire'; // ou 'Agent immo'

  final _prenomController = TextEditingController();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _animCtrl,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    for (final c in [
      _prenomController,
      _nomController,
      _emailController,
      _phoneController,
      _passwordController,
      _confirmController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── LOGIQUE ──────────────────────────────────────────

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      _showLogin ? await _handleLogin() : await _handleRegister();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleLogin() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text.trim(),
      );
      final name =
          _auth.currentUser?.displayName ??
          _emailController.text.split('@').first;
      _showSnack('Connexion réussie ✅');
      _goToAcceuil(name);
      // _goToAcceuil(name);
    } on FirebaseAuthException catch (e) {
      await _showError(_authMessage(e));
    }
  }

  Future<void> _handleRegister() async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text.trim(),
      );
      final displayName =
          '${_prenomController.text.trim()} ${_nomController.text.trim()}';
      await cred.user?.updateDisplayName(displayName);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
            'displayName': displayName,
            'email': _emailController.text.trim().toLowerCase(),
            'phone': _phoneController.text.trim(),
            'role': _role,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      _showSnack('Inscription réussie 🎉');
      _goToAcceuil(displayName);
      // _goToDashboard(displayName);
    } on FirebaseAuthException catch (e) {
      _showSnack(_authMessage(e));
    }
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Email ou mot de passe incorrect';
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet email';
      case 'email-already-in-use':
        return 'Email déjà utilisé. Connectez-vous.';
      case 'weak-password':
        return 'Mot de passe trop court (min. 6 car.)';
      case 'invalid-email':
        return 'Adresse email invalide';
      case 'network-request-failed':
        return 'Connexion internet indisponible';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      default:
        return e.message ?? 'Erreur: ${e.code}';
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _showError(String msg) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Connexion impossible'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _showLogin = !_showLogin;
      for (final c in [
        _prenomController,
        _nomController,
        _emailController,
        _phoneController,
        _passwordController,
        _confirmController,
      ]) {
        c.clear();
      }
      _showPassword = false;
      _showConfirmPassword = false;
    });
    _animCtrl
      ..reset()
      ..forward();
  }

  // ── BUILD ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── HERO SECTION (fond navy) ──────────────
              _buildHero(),

              // ── CARD FORMULAIRE (fond blanc arrondi) ──
              _buildFormCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ── HERO : logo + titre ───────────────────────────────
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 48, 24, 32),
      child: Column(
        children: [
          // Cercle jaune avec logo
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: AppColors.cream,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                'assets/images/logo (2).png',
                width: 60,
                height: 60,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _showLogin ? 'Gestion locatives' : 'Creer un compte',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Service & Sérénité',
            style: TextStyle(fontSize: 14, color: Color(0xFFB0BAD0)),
          ),
        ],
      ),
    );
  }

  // ── CARD FORMULAIRE ───────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre de la card
              Text(
                _showLogin ? 'Connexion' : 'Je suis',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 20),

              // ── INSCRIPTION : sélection rôle ─────────
              if (!_showLogin) ...[
                _buildRoleSelector(),
                const SizedBox(height: 20),
                _buildSectionTitle('INFORMATION'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _input(
                        controller: _prenomController,
                        hint: 'Prenom',
                        validator: (v) => _req(v, 'Prénom'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _input(
                        controller: _nomController,
                        hint: 'Nom',
                        validator: (v) => _req(v, 'Nom'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _input(
                  controller: _phoneController,
                  hint: 'Téléphone',
                  keyboardType: TextInputType.phone,
                  validator: (v) => _req(v, 'Téléphone'),
                ),
                const SizedBox(height: 10),
                _input(
                  controller: _emailController,
                  hint: 'E-mail',
                  keyboardType: TextInputType.emailAddress,
                  validator: _emailValidator,
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('Sécurité'),
                const SizedBox(height: 12),
                _input(
                  controller: _passwordController,
                  hint: 'Mot de passe',
                  obscure: !_showPassword,
                  suffixIcon: _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onSuffix: () =>
                      setState(() => _showPassword = !_showPassword),
                  validator: _pwdValidator,
                ),
                const SizedBox(height: 10),
                _input(
                  controller: _confirmController,
                  hint: 'Confirmer',
                  obscure: !_showConfirmPassword,
                  suffixIcon: _showConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onSuffix: () => setState(
                    () => _showConfirmPassword = !_showConfirmPassword,
                  ),
                  validator: _confirmValidator,
                ),
                const SizedBox(height: 28),
              ],

              // ── CONNEXION : champs email + mdp ────────
              if (_showLogin) ...[
                _buildSectionLabel('EMAIL'),
                const SizedBox(height: 6),
                _input(
                  controller: _emailController,
                  hint: 'votre@gmail.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: _emailValidator,
                ),
                const SizedBox(height: 16),
                _buildSectionLabel('Mot de passe'),
                const SizedBox(height: 6),
                _input(
                  controller: _passwordController,
                  hint: '••••••••••',
                  obscure: !_showPassword,
                  suffixIcon: _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onSuffix: () =>
                      setState(() => _showPassword = !_showPassword),
                  validator: _pwdValidator,
                ),
                const SizedBox(height: 28),
              ],

              // ── BOUTON PRINCIPAL ──────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cream,
                    disabledBackgroundColor: AppColors.cream.withValues(
                      alpha: 0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.navy,
                          ),
                        )
                      : Text(
                          _showLogin ? 'Se coconnecter' : 'Creer un compte',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // ── LIENS BAS DE CARD ─────────────────────
              if (_showLogin) ...[
                Center(
                  child: TextButton(
                    onPressed: () {
                      /* reset password */
                    },
                    child: const Text(
                      'Mot de passe oublié?',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],

              GestureDetector(
                onTap: _toggleMode,
                child: Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      children: [
                        TextSpan(
                          text: _showLogin
                              ? 'Pas de compte?  '
                              : 'Deja compte?  ',
                        ),
                        TextSpan(
                          text: _showLogin ? 'S\'inscrire' : 'Se connecter',
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SOUS-WIDGETS ──────────────────────────────────────

  Widget _buildRoleSelector() {
    return Row(
      children: [
        Expanded(child: _roleBtn('Propretaire')),
        const SizedBox(width: 12),
        Expanded(child: _roleBtn('Agent immo')),
      ],
    );
  }

  Widget _roleBtn(String label) {
    final selected = _role == label;
    return GestureDetector(
      onTap: () => setState(() => _role = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.cream : AppColors.creamLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.creamBorder : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: selected ? AppColors.navy : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.navy,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    bool obscure = false,
    IconData? suffixIcon,
    VoidCallback? onSuffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: AppColors.textMain),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        filled: true,
        fillColor: AppColors.inputFill,
        suffixIcon: suffixIcon == null
            ? null
            : IconButton(
                icon: Icon(suffixIcon, color: AppColors.textMuted, size: 20),
                onPressed: onSuffix,
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
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
            color: AppColors.creamBorder,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.8),
        ),
      ),
    );
  }

  // ── VALIDATORS ──────────────────────────────────────

  String? _req(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field requis';
    return null;
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email requis';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
      return 'Email invalide';
    }
    return null;
  }

  String? _pwdValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Mot de passe requis';
    if (v.length < 6) return 'Minimum 6 caractères';
    return null;
  }

  String? _confirmValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Confirmation requise';
    if (v.trim() != _passwordController.text.trim()) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }
}
