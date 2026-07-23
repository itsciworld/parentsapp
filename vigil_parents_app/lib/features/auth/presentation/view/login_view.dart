import 'package:flexi_form_field/flexi_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/core/appColor/app_theme/app_gradient.dart';
import 'package:vigil_parents_app/core/appimages/app_images.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/core/routing/routes.dart';
import 'package:vigil_parents_app/core/utils/validators.dart';

import 'package:vigil_parents_app/features/auth/presentation/view_model/auth_viewmodel.dart';
import 'package:vigil_parents_app/globle_components/custom_button/custombutton.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  static const Color _darkNavy = Color(0xFF1A237E);

  static const Color _accentGreen = Color(0xFF15BEB5);
  static const Color _accentBlue = Color(0xFF2BA0CC);

  // Shared FlexiFormTheme for all fields
  FlexiFormTheme get _fieldTheme => FlexiFormTheme(
    primaryColor: _darkNavy,
    borderRadius: const BorderRadius.all(Radius.circular(10)),
    fillColor: Colors.grey.shade50,
    labelStyle: const TextStyle(color: Colors.black87),
    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    ref.read(authViewModelProvider.notifier).login(email, password);
  }

  @override
  Widget build(BuildContext context) {
    // ── Responsiveness ──────────────────────────────────────────────────────
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;
    final isSmall = screenH < 680;

    final hPad = screenW * 0.06; // horizontal padding ~6% of width
    final logoBoxH = screenH * 0.30; // logo area 30% of height
    final vGapSm = screenH * 0.015;
    final vGapMd = screenH * 0.022;

    // ── State listener ──────────────────────────────────────────────────────
    ref.listen<AuthState>(authViewModelProvider, (previous, next) async {
      // Show Toast
      if (next.toastData != null && next.toastData != previous?.toastData) {
        showAppToast(
          context: context,
          title: next.toastData!.title,
          subtitle: next.toastData!.subtitle,
          type: next.toastData!.type,
        );
      }

      // Navigate on success (ONLY once)
      if (next.isSuccess && !(previous?.isSuccess ?? false)) {
        // final email = await SecureDeviceService.getEmail();
        // final token = await SecureDeviceService.getToken();
        // final parentId = await SecureDeviceService.getParentId();
        // final parentName = await SecureDeviceService.getParentName();

        if (!mounted) return;
        Navigator.pushNamed(context, AppRoutesName.homeView);

        // Navigator.pushReplacementNamed(
        //   context,
        //   '/devicespage',
        //   arguments: {
        //     'email': email,
        //     'token': token,
        //     'parentId': parentId,
        //     'parent_name': parentName,
        //   },
        // );
      }
    });

    final authState = ref.watch(authViewModelProvider);

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
                      // ── Hero Section ─────────────────────────────
                      _HeroSection(
                        height: logoBoxH,
                        darkNavy: _darkNavy,
                        accentBlue: _accentBlue,
                      ),

                      // ── Main Content ────────────────────────────
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
                                  'Welcome Back!',
                                  style: TextStyle(
                                    fontSize: isSmall ? 22 : 26,
                                    fontWeight: FontWeight.w800,
                                    color: _darkNavy,
                                  ),
                                ),

                                SizedBox(height: 4),

                                Text(
                                  'Login to your account to continue',
                                  style: TextStyle(
                                    fontSize: isSmall ? 12 : 13.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),

                                SizedBox(height: vGapMd),

                                FieldLabel(text: 'Email', required: true),
                                SizedBox(height: 6),

                                FlexiFormField(
                                  controller: _emailController,
                                  hint: 'Enter Your Email',
                                  isEmail: true,
                                  isMandatory: true,
                                  denySpace: true,
                                  validator: Validators.email,
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

                                FieldLabel(text: 'Password', required: true),
                                SizedBox(height: 6),

                                // 2. Replace the password FlexiFormField with this
                                FlexiFormField(
                                  // label: 'hellow',
                                  controller: _passwordController,
                                  hint: 'Enter Your Password',
                                  obscureText:
                                      _obscurePassword, // ← bind to state bool
                                  isMandatory: true,
                                  validator: Validators.password,
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
                                  // autoValidate: true,
                                ),

                                SizedBox(height: vGapSm),

                                Row(
                                  children: [
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        AppRoutesName.forgotPasswordView,
                                      ),
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _accentBlue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: vGapMd * 1.4),

                                CustomButton(
                                  onTap: authState.isLoading
                                      ? null
                                      : _handleLogin,
                                  isLoading: authState.isLoading,
                                  label: 'Login',
                                  height: screenH * 0.053,
                                  gradient: AppGradients.primaryButton,
                                ),

                                SizedBox(height: vGapMd),

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

                                Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Don't have an Account? ",
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.pushNamed(
                                          context,
                                          AppRoutesName.signupView,
                                        ),
                                        child: Text(
                                          'Sign up',
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
// Hero / Logo Section
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
          // SizedBox(height: 60),
          // Background wavy blobs (decorative)
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
          // Centred logo
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10), // ← yahan se space do
              child: Container(
                width: height * 0.99,
                height: height * 0.99,
                padding: const EdgeInsets.all(1),
                child: Image.asset(AppImages.logo, fit: BoxFit.contain),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Decorative blob widget
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
// Field label helper
// ---------------------------------------------------------------------------

class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.text, this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        children: required
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]
            : null,
      ),
    );
  }
}
