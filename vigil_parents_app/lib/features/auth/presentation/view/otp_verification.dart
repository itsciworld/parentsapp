import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import 'package:vigil_parents_app/core/appColor/app_theme/app_gradient.dart';
import 'package:vigil_parents_app/core/appimages/app_images.dart';
import 'package:vigil_parents_app/globle_components/custom_button/custombutton.dart';

class OtpVerificationView extends ConsumerStatefulWidget {
  const OtpVerificationView({super.key});

  @override
  ConsumerState<OtpVerificationView> createState() =>
      _OtpVerificationViewState();
}

class _OtpVerificationViewState extends ConsumerState<OtpVerificationView> {
  final TextEditingController _otpController = TextEditingController();

  // Brand Colours
  static const Color _darkNavy = Color(0xFF1A237E);
  static const Color _accentGreen = Color(0xFF15BEB5);
  static const Color _accentBlue = Color(0xFF2BA0CC);

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _handleVerifyOtp() {
    FocusScope.of(context).unfocus();

    final otp = _otpController.text.trim();

    if (otp.length < 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter valid OTP')));
      return;
    }

    debugPrint(otp);

    // TODO: Verify OTP API
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    final screenH = mq.size.height;
    final screenW = mq.size.width;

    final isSmall = screenH < 680;

    final hPad = screenW * 0.06;
    final logoBoxH = screenH * 0.28;
    final vGapMd = screenH * 0.022;

    final defaultPinTheme = PinTheme(
      width: screenW * 0.16,
      height: screenH * 0.07,
      textStyle: TextStyle(
        fontSize: isSmall ? 20 : 22,
        fontWeight: FontWeight.w700,
        color: _darkNavy,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // ───────────── Hero Section ─────────────
                      _HeroSection(
                        height: logoBoxH,
                        darkNavy: _darkNavy,
                        accentBlue: _accentBlue,
                      ),

                      // ───────────── Main Content ─────────────
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: vGapMd * 1.2),

                              Text(
                                'OTP Verification',
                                style: TextStyle(
                                  fontSize: isSmall ? 22 : 26,
                                  fontWeight: FontWeight.w800,
                                  color: _darkNavy,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                'Enter the verification code sent to your email',
                                style: TextStyle(
                                  fontSize: isSmall ? 12 : 13.5,
                                  color: Colors.grey.shade600,
                                ),
                              ),

                              SizedBox(height: vGapMd * 1.8),

                              // ───────────── OTP FIELD ─────────────
                              Center(
                                child: Pinput(
                                  controller: _otpController,
                                  length: 4,
                                  defaultPinTheme: defaultPinTheme,

                                  focusedPinTheme: defaultPinTheme
                                      .copyDecorationWith(
                                        border: Border.all(
                                          color: _accentBlue,
                                          width: 1.5,
                                        ),
                                      ),

                                  submittedPinTheme: defaultPinTheme
                                      .copyDecorationWith(
                                        border: Border.all(color: _accentGreen),
                                      ),

                                  separatorBuilder: (index) =>
                                      SizedBox(width: screenW * 0.025),

                                  keyboardType: TextInputType.number,

                                  autofocus: true,
                                ),
                              ),

                              SizedBox(height: vGapMd * 0.9),

                              // ───────────── RESEND ─────────────
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Didn't receive code? ",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),

                                    GestureDetector(
                                      onTap: () {
                                        // TODO: resend otp
                                      },
                                      child: Text(
                                        'Resend',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _accentGreen,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: vGapMd * 1.8),

                              // ───────────── VERIFY BUTTON ─────────────
                              CustomButton(
                                onTap: _handleVerifyOtp,
                                label: 'Verify OTP',
                                height: screenH * 0.053,
                                gradient: AppGradients.primaryButton,
                                isLoading: false,
                              ),

                              SizedBox(height: vGapMd),

                              // ───────────── BACK ─────────────
                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    'Back',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: _accentGreen,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: vGapMd),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Section
// ---------------------------------------------------------------------------

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.height,
    required this.darkNavy,
    required this.accentBlue,
  });

  final double height;
  final Color darkNavy;
  final Color accentBlue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Left Blob
          Positioned(
            bottom: -20,
            left: -30,
            child: _Blob(size: height * 0.6, color: const Color(0xFFEBF6FF)),
          ),

          // Right Blob
          Positioned(
            bottom: -10,
            right: -20,
            child: _Blob(
              size: height * 0.5,
              color: const Color(0xFFBAE4C8).withValues(alpha: 0.16),
            ),
          ),

          // Logo
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: height * 0.95,
                height: height * 0.95,
                child: Image.asset(AppImages.logo, fit: BoxFit.contain),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Blob Widget
// ---------------------------------------------------------------------------

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
