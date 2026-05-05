import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/features/auth/presentation/view_model/auth_viewmodel.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  bool _obscureText = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to state changes to handle navigation or errors
    ref.listen<LoginState>(loginViewModelProvider, (previous, next) async {
      if (next.toastData != null && next.toastData != previous?.toastData) {
        showAppToast(
          context: context,
          title: next.toastData!.title,
          subtitle: next.toastData!.subtitle,
          type: next.toastData!.type,
        );
      }

      if (next.isSuccess && !(previous?.isSuccess ?? false)) {
        // Fetch params from SecureDeviceService
        final email = await SecureDeviceService.getEmail();
        final token = await SecureDeviceService.getToken();
        final parentId = await SecureDeviceService.getParentId();
        final parentName = await SecureDeviceService.getParentName();

        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/devicespage',
            arguments: {
              'email': email,
              'token': token,
              'parentId': parentId,
              'parent_name': parentName,
            },
          );
        }
      }
    });

    final loginState = ref.watch(loginViewModelProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 60),
            const Text(
              'Protect Your Child With',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Vigil 1',
              style: TextStyle(
                fontSize: 42,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w900,
                color: Color.fromRGBO(43, 160, 204, 1),
                height: 1,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sign in to get started.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'jhondoe@gmail.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/send_code');
                },
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(color: Colors.blue, fontSize: 14),
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dont have an account?',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/registration');
                  },
                  child: const Text(
                    'Register',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color.fromRGBO(21, 190, 181, 1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loginState.isLoading
                      ? null
                      : () {
                          // Unfocus keyboard before starting login
                          FocusScope.of(context).unfocus();

                          final email = _emailController.text.trim();
                          final password = _passwordController.text;

                          if (email.isEmpty || password.isEmpty) {
                            showAppToast(
                              context: context,
                              title: 'Missing Fields',
                              subtitle: 'Please enter both email and password.',
                              type: ToastType.warning,
                            );
                            return;
                          }

                          ref
                              .read(loginViewModelProvider.notifier)
                              .login(email, password);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 60),
                  ),
                  child: loginState.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Sign In',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
