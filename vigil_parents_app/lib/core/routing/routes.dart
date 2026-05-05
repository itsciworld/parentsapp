import 'package:flutter/material.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/login_view.dart';
import 'package:vigil_parents_app/features/introduction/presentation/view/intro_view.dart';

class AppRoutesName {
  static const String introView = '/introView';
  static const String loginView = '/loginView';
}

class AppRouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutesName.introView:
        return MaterialPageRoute(builder: (_) => IntroView());
      case AppRoutesName.loginView:
        return MaterialPageRoute(builder: (_) => LoginView());
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found!'))),
        );
    }
  }
}
