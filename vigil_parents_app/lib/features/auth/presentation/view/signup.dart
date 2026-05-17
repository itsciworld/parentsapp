import 'package:flexi_form_field/flexi_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/core/appColor/app_theme/app_gradient.dart';
import 'package:vigil_parents_app/core/appimages/app_images.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/core/routing/routes.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/login_view.dart';
import 'package:vigil_parents_app/features/auth/presentation/view_model/auth_viewmodel.dart';
import 'package:vigil_parents_app/globle_components/custom_button/custombutton.dart';

class SignupView extends ConsumerStatefulWidget {
  const SignupView({super.key});

  @override
  ConsumerState<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends ConsumerState<SignupView> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Brand colours
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignup() {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    ref.read(authViewModelProvider.notifier).register(name, email, password);
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
    final authState = ref.watch(authViewModelProvider);
    ref.listen<AuthState>(authViewModelProvider, (previous, next) async {
      // Toast
      if (next.toastData != null && next.toastData != previous?.toastData) {
        showAppToast(
          context: context,
          title: next.toastData!.title,
          subtitle: next.toastData!.subtitle,
          type: next.toastData!.type,
        );
      }

      // Navigate after success
      if (next.isSuccess && !(previous?.isSuccess ?? false)) {
        final navigator = Navigator.of(context);
        final email = await SecureDeviceService.getEmail();
        final token = await SecureDeviceService.getToken();
        final parentId = await SecureDeviceService.getParentId();
        final parentName = await SecureDeviceService.getParentName();

        if (!mounted) return;

        navigator.pushReplacementNamed(AppRoutesName.homeView);
      }
    });

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
                      // ───────────────── Hero Section ─────────────────
                      _HeroSection(
                        height: logoBoxH,
                        darkNavy: _darkNavy,
                        accentBlue: _accentBlue,
                      ),

                      // ───────────────── Main Content ─────────────────
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
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: isSmall ? 22 : 26,
                                    fontWeight: FontWeight.w800,
                                    color: _darkNavy,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  'Create your account to continue',
                                  style: TextStyle(
                                    fontSize: isSmall ? 12 : 13.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),

                                SizedBox(height: vGapMd),

                                // ───────────── Name ─────────────
                                const FieldLabel(
                                  text: 'Full Name',
                                  required: true,
                                ),
                                const SizedBox(height: 6),

                                FlexiFormField(
                                  controller: _nameController,
                                  hint: 'Enter Your Name',
                                  isMandatory: true,
                                  fieldStyle: FlexiFieldStyle.outline,
                                  theme: _fieldTheme,
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                    size: 20,
                                    color: Colors.grey.shade500,
                                  ),
                                ),

                                SizedBox(height: vGapSm),

                                // ───────────── Email ─────────────
                                const FieldLabel(text: 'Email', required: true),
                                const SizedBox(height: 6),

                                FlexiFormField(
                                  controller: _emailController,
                                  hint: 'Enter Your Email',
                                  isEmail: true,
                                  isMandatory: true,
                                  denySpace: true,
                                  keyboardType: TextInputType.emailAddress,
                                  fieldStyle: FlexiFieldStyle.outline,
                                  theme: _fieldTheme,
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    size: 20,
                                    color: Colors.grey.shade500,
                                  ),
                                ),

                                SizedBox(height: vGapSm),

                                // ───────────── Password ─────────────
                                const FieldLabel(
                                  text: 'Password',
                                  required: true,
                                ),
                                const SizedBox(height: 6),

                                FlexiFormField(
                                  controller: _passwordController,
                                  hint: 'Enter Your Password',
                                  obscureText: _obscurePassword,
                                  isMandatory: true,
                                  fieldStyle: FlexiFieldStyle.outline,
                                  theme: _fieldTheme,
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
                                  prefixIcon: Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                    color: Colors.grey.shade500,
                                  ),
                                ),

                                SizedBox(height: vGapMd * 1.5),

                                // ───────────── Signup Button ─────────────
                                CustomButton(
                                  onTap: authState.isLoading
                                      ? null
                                      : _handleSignup,
                                  label: 'Create Account',
                                  height: screenH * 0.053,
                                  gradient: AppGradients.primaryButton,
                                  isLoading: authState.isLoading,
                                ),

                                SizedBox(height: vGapMd),

                                // ───────────── OR Divider ─────────────
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'OR',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: vGapMd),

                                // ───────────── Login Redirect ─────────────
                                Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Already have an Account? ",
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            AppRoutesName.loginView,
                                          );
                                        },
                                        child: Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: _accentGreen,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
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

// ---------------------------------------------------------------------------
// Field Label
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }
}
