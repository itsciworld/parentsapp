import 'package:flutter/material.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/forgot_pass.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/login_view.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/signup.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/splash_view.dart';
import 'package:vigil_parents_app/features/introduction/presentation/view/intro_view.dart';

class AppRoutesName {
  static const String introView = '/introView';
  static const String loginView = '/loginView';
  static const String signupView = '/signupView';
  static const String forgotPasswordView = '/forgotPasswordView';
  static const String splashView = '/splashView';
}

class AppRouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutesName.introView:
        return MaterialPageRoute(builder: (_) => IntroView());
      case AppRoutesName.loginView:
        return MaterialPageRoute(builder: (_) => LoginView());
      case AppRoutesName.signupView:
        return MaterialPageRoute(builder: (_) => SignupView());
      case AppRoutesName.forgotPasswordView:
        return MaterialPageRoute(builder: (_) => ForgotPasswordView());
      case AppRoutesName.splashView:
        return MaterialPageRoute(builder: (_) => SplashView());
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found!'))),
        );
    }
  }
}
