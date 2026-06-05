import 'package:flutter/material.dart';
import 'dart:math' as math;

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  late AnimationController _orbitController;
  late AnimationController _breatheController;
  late AnimationController _fadeController;
  late AnimationController _waveController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _breatheAnimation;

  int _activePills = 0;

  @override
  void initState() {
    super.initState();

    _orbitController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat();

    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _breatheAnimation = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    _fadeController.forward();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _activePills = 1);
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _activePills = 2);
    });
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _activePills = 3);
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/connect');
    });
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _breatheController.dispose();
    _fadeController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF132040),
      body: Center(
        child: AnimatedBuilder(
          animation: _fadeController,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOrbitLogo(),
              const SizedBox(height: 36),
              const Text(
                'Gestion Locative',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Biens · Locataires · Paiements',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0x66FFFFFF),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 40),
              _buildWaveEqualizer(),
              const SizedBox(height: 36),
              _buildPills(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrbitLogo() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _orbitController,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(140, 140),
                painter: _OrbitDotsPainter(_orbitController.value),
              );
            },
          ),
          AnimatedBuilder(
            animation: _breatheAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _breatheAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF2C94C),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Image(
                image: AssetImage('assets/images/logo (2).png'),
                width: 32,
                height: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveEqualizer() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final delays = [0.0, 0.15, 0.3, 0.45, 0.6, 0.45, 0.3];
            final phase = (_waveController.value + delays[i]) % 1.0;
            final height = 8.0 + 16.0 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi));
            return Container(
              width: 4,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF2C94C),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildPills() {
    final modules = [
      (Icons.home_outlined, 'Biens'),
      (Icons.people_outline, 'Locataires'),
      (Icons.credit_card_outlined, 'Paiements'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: modules.asMap().entries.map((entry) {
        final index = entry.key;
        final module = entry.value;
        final isActive = index < _activePills;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFF2C94C)
                  : const Color(0x4DF2C94C),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                module.$1,
                size: 13,
                color: isActive
                    ? const Color(0xFFF2C94C)
                    : const Color(0x8DFFFFFF),
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 400),
                style: TextStyle(
                  fontSize: 12,
                  color: isActive
                      ? const Color(0xFFF2C94C)
                      : const Color(0x8DFFFFFF),
                ),
                child: Text(module.$2),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _OrbitDotsPainter extends CustomPainter {
  final double progress;
  _OrbitDotsPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 58.0;

    final dots = [
      (0.0, const Color(0xFFF2C94C), 11.0),
      (2 * math.pi / 3, const Color(0x8CF2C94C), 9.0),
      (4 * math.pi / 3, const Color(0x40F2C94C), 7.0),
    ];

    for (final dot in dots) {
      final angle = dot.$1 + progress * 2 * math.pi;
      final pos = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawCircle(pos, dot.$3 / 2, Paint()..color = dot.$2);
    }
  }

  @override
  bool shouldRepaint(_OrbitDotsPainter old) => old.progress != progress;
}
