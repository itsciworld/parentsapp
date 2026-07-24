import 'package:flexi_form_field/flexi_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/core/appColor/app_theme/app_gradient.dart';
import 'package:vigil_parents_app/core/appimages/app_images.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/core/routing/routes.dart';
import 'package:vigil_parents_app/core/utils/validators.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/login_view.dart';
import 'package:vigil_parents_app/features/auth/presentation/view_model/forgot_password_viewmodel.dart';
import 'package:vigil_parents_app/globle_components/custom_button/custombutton.dart';

class ResetPasswordView extends ConsumerStatefulWidget {
  /// Email + verified OTP carried from the previous steps of the flow.
  final String email;
  final String otp;

  const ResetPasswordView({super.key, required this.email, required this.otp});

  @override
  ConsumerState<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends ConsumerState<ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Brand Colours
  static const Color _darkNavy = Color(0xFF1A237E);
  static const Color _accentGreen = Color(0xFF15BEB5);
  static const Color _accentBlue = Color(0xFF2BA0CC);

  FlexiFormTheme get _fieldTheme => FlexiFormTheme(
    primaryColor: _darkNavy,
    borderRadius: const BorderRadius.all(Radius.circular(10)),
    fillColor: Colors.grey.shade50,
    labelStyle: const TextStyle(color: Colors.black87),
    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
  );

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _handleResetPassword() {
    FocusScope.of(context).unfocus();

    // The confirm field validates the match inline, so a failed validate()
    // has already shown the reason on the offending field.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final password = _passwordController.text;

    ref
        .read(forgotPasswordViewModelProvider.notifier)
        .resetPassword(widget.email, widget.otp, password);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    final screenH = mq.size.height;
    final screenW = mq.size.width;

    final isSmall = screenH < 680;

    final hPad = screenW * 0.06;
    final logoBoxH = screenH * 0.28;
    final vGapSm = screenH * 0.015;
    final vGapMd = screenH * 0.022;

    // ── State listener: toast + back to login on success ───────────────────
    ref.listen<ForgotPasswordState>(forgotPasswordViewModelProvider, (
      previous,
      next,
    ) {
      if (next.toastData != null && next.toastData != previous?.toastData) {
        showAppToast(
          context: context,
          title: next.toastData!.title,
          subtitle: next.toastData!.subtitle,
          type: next.toastData!.type,
        );
      }

      if (next.passwordReset && !(previous?.passwordReset ?? false)) {
        // Clear the flow state and return to the login screen.
        ref.read(forgotPasswordViewModelProvider.notifier).reset();
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutesName.loginView,
          (route) => false,
        );
      }
    });

    final forgotState = ref.watch(forgotPasswordViewModelProvider);

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
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: vGapMd * 1.2),

                                Text(
                                  'Create New Password',
                                  style: TextStyle(
                                    fontSize: isSmall ? 22 : 26,
                                    fontWeight: FontWeight.w800,
                                    color: _darkNavy,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  'Set a new password for your account',
                                  style: TextStyle(
                                    fontSize: isSmall ? 12 : 13.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),

                                SizedBox(height: vGapMd),

                                // ───────────── New Password ─────────────
                                FieldLabel(
                                  text: 'New Password',
                                  required: true,
                                ),

                                const SizedBox(height: 6),

                                FlexiFormField(
                                  controller: _passwordController,
                                  hint: 'Enter New Password',
                                  obscureText: _obscurePassword,
                                  isMandatory: true,
                                  // No `denySpace` — a pasted payload such as
                                  // `' OR 1=1 --` must reach the validator so
                                  // it is rejected with a reason, rather than
                                  // being silently stripped of its spaces.
                                  validator: Validators.newPassword,
                                  fieldStyle: FlexiFieldStyle.outline,
                                  theme: _fieldTheme,
                                  prefixIcon: Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                    color: Colors.grey.shade500,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey.shade500,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),

                                SizedBox(height: vGapSm),

                                // ─────────── Confirm Password ───────────
                                FieldLabel(
                                  text: 'Confirm Password',
                                  required: true,
                                ),

                                const SizedBox(height: 6),

                                FlexiFormField(
                                  controller: _confirmController,
                                  hint: 'Re-enter New Password',
                                  obscureText: _obscureConfirm,
                                  isMandatory: true,
                                  validator: (value) =>
                                      Validators.confirmPassword(
                                        value,
                                        _passwordController.text,
                                      ),
                                  fieldStyle: FlexiFieldStyle.outline,
                                  theme: _fieldTheme,
                                  prefixIcon: Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                    color: Colors.grey.shade500,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey.shade500,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirm = !_obscureConfirm;
                                      });
                                    },
                                  ),
                                ),

                                SizedBox(height: vGapMd * 1.6),

                                // ───────────── Submit Button ─────────────
                                CustomButton(
                                  onTap: forgotState.isLoading
                                      ? null
                                      : _handleResetPassword,
                                  label: 'Reset Password',
                                  height: screenH * 0.053,
                                  gradient: AppGradients.primaryButton,
                                  isLoading: forgotState.isLoading,
                                ),

                                SizedBox(height: vGapMd),

                                // ───────────── Back To Login ─────────────
                                Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                    },
                                    child: Text(
                                      'Back to Login',
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
