import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appimages/app_images.dart';
import 'package:vigil_parents_app/core/routing/routes.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  static const Color _darkBlue = Color(0xFF0B2C6B);
  static const Color _green = Color(0xFF46B72A);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutesName.introView);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    final screenH = mq.size.height;
    final screenW = mq.size.width;

    final isSmall = screenH < 700;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: double.infinity,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  // ───────────────── TOP SPACE ─────────────────
                  SizedBox(height: screenH * 0.05),

                  // ───────────────── LOGO ─────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenW * 0.02),
                    child: Image.asset(
                      AppImages.logo,
                      fit: BoxFit.contain,
                      height: screenH * 0.30,
                    ),
                  ),

                  SizedBox(height: screenH * 0.025),

                  // ───────────────── BANNER CARD ─────────────────
                  Container(
                    width: double.infinity,
                    // padding: EdgeInsets.all(screenW * 0.03),
                    decoration: BoxDecoration(
                      // color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        // BoxShadow(
                        //   color: Colors.black.withValues(alpha: 0.06),
                        //   blurRadius: 18,
                        //   offset: const Offset(0, 8),
                        // ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        AppImages.splashBanner,
                        fit: BoxFit.cover,
                        height: screenH * 0.25,
                        width: double.infinity,
                      ),
                    ),
                  ),

                  SizedBox(height: screenH * 0.045),

                  // ───────────────── TITLE ─────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenW * 0.08),
                    child: Column(
                      children: [
                        Text(
                          'Because Your Safety',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmall ? 28 : 34,
                            fontWeight: FontWeight.w800,
                            color: _darkBlue,
                            height: 1.1,
                          ),
                        ),

                        SizedBox(height: screenH * 0.008),

                        Text(
                          'Is Your Peace of Mind',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmall ? 24 : 30,
                            fontWeight: FontWeight.w700,
                            color: _green,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ───────────────── LOADER ─────────────────
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: _green,
                    ),
                  ),

                  SizedBox(height: screenH * 0.06),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
