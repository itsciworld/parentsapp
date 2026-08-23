import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import 'package:vigil_parents_app/core/appColor/app_theme/app_gradient.dart';
import 'package:vigil_parents_app/core/appimages/app_images.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/core/routing/routes.dart';
import 'package:vigil_parents_app/features/auth/presentation/view_model/register_viewmodel.dart';
import 'package:vigil_parents_app/globle_components/custom_button/custombutton.dart';

/// Step 2 of registration. Carries the credentials entered on the signup
/// screen because `/api/auth/register-website` needs all four fields at once —
/// nothing was created server-side by the send-OTP call.
class RegisterOtpView extends ConsumerStatefulWidget {
  final String name;
  final String email;
  final String password;

  const RegisterOtpView({
    super.key,
    required this.name,
    required this.email,
    required this.password,
  });

  @override
  ConsumerState<RegisterOtpView> createState() => _RegisterOtpViewState();
}

class _RegisterOtpViewState extends ConsumerState<RegisterOtpView> {
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
    // Pinput's onCompleted can fire while a resend is still in flight.
    if (ref.read(registerViewModelProvider).isResending) return;

    FocusScope.of(context).unfocus();

    final otp = _otpController.text.trim();

    if (otp.length < 6) {
      showAppToast(
        context: context,
        title: 'Invalid OTP',
        subtitle: 'Please enter the 6-digit code sent to your email',
        type: ToastType.warning,
      );
      return;
    }

    ref
        .read(registerViewModelProvider.notifier)
        .registerWithOtp(
          name: widget.name,
          email: widget.email,
          password: widget.password,
          otp: otp,
        );
  }

  void _handleResend() {
    FocusScope.of(context).unfocus();
    _otpController.clear();
    ref
        .read(registerViewModelProvider.notifier)
        .sendRegisterOtp(widget.name, widget.email, isResend: true);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    // ── State listener: toast + straight to the dashboard on success ────────
    ref.listen<RegisterState>(registerViewModelProvider, (previous, next) {
      if (next.toastData != null && next.toastData != previous?.toastData) {
        showAppToast(
          context: context,
          title: next.toastData!.title,
          subtitle: next.toastData!.subtitle,
          type: next.toastData!.type,
        );
      }

      // A 201 already stored the token, so the user is logged in — drop the
      // whole auth stack so back from the dashboard can't return to signup.
      if (next.isRegistered && !(previous?.isRegistered ?? false)) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutesName.homeView,
          (_) => false,
        );
      }
    });

    final registerState = ref.watch(registerViewModelProvider);

    final screenH = mq.size.height;
    final screenW = mq.size.width;

    final isSmall = screenH < 680;

    final hPad = screenW * 0.06;
    final logoBoxH = screenH * 0.28;
    final vGapMd = screenH * 0.022;

    final defaultPinTheme = PinTheme(
      width: screenW * 0.12,
      height: screenH * 0.065,
      textStyle: TextStyle(
        fontSize: isSmall ? 18 : 20,
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
                                'Verify Your Email',
                                style: TextStyle(
                                  fontSize: isSmall ? 22 : 26,
                                  fontWeight: FontWeight.w800,
                                  color: _darkNavy,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text.rich(
                                TextSpan(
                                  text: 'Enter the 6-digit code we sent to ',
                                  children: [
                                    TextSpan(
                                      text: widget.email,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: _darkNavy,
                                      ),
                                    ),
                                  ],
                                ),
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
                                  length: 6,
                                  defaultPinTheme: defaultPinTheme,
                                  onCompleted: (_) => _handleVerifyOtp(),

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
                                      SizedBox(width: screenW * 0.015),

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

                                    // The resend spinner takes the link's place
                                    // so the verify button never flickers.
                                    if (registerState.isResending)
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                _accentGreen,
                                              ),
                                        ),
                                      )
                                    else
                                      GestureDetector(
                                        onTap: registerState.isLoading
                                            ? null
                                            : _handleResend,
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
                                onTap:
                                    registerState.isLoading ||
                                        registerState.isResending
                                    ? null
                                    : _handleVerifyOtp,
                                label: 'Verify & Create Account',
                                height: screenH * 0.053,
                                gradient: AppGradients.primaryButton,
                                isLoading: registerState.isLoading,
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
