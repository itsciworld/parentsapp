import 'package:flutter/material.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/forgot_pass.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/login_view.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/otp_verification.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/reset_password_view.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/signup.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/splash_view.dart';
import 'package:vigil_parents_app/features/calls/presentation/view_model/view/calls_view.dart';
import 'package:vigil_parents_app/features/child/presentation/view/child_view.dart';
import 'package:vigil_parents_app/features/contact/view/contact_view.dart';
import 'package:vigil_parents_app/features/gallery/presentations/view/gallery_view.dart';
import 'package:vigil_parents_app/features/introduction/presentation/view/intro_view.dart';
import 'package:vigil_parents_app/features/main_shell/main_shell.dart';
import 'package:vigil_parents_app/features/profile/presentation/view/profile_view.dart';
import 'package:vigil_parents_app/features/settings/presentation/view/settings_view.dart';
import 'package:vigil_parents_app/features/sms/view/sms_view.dart';

class AppRoutesName {
  static const String introView = '/introView';
  static const String loginView = '/loginView';
  static const String signupView = '/signupView';
  static const String forgotPasswordView = '/forgotPasswordView';
  static const String splashView = '/splashView';
  static const String otpVerificationView = '/otpVerificationView';
  static const String resetPasswordView = '/resetPasswordView';
  static const String homeView = '/homeView';
  static const String smsView = '/smsView';
  static const String callView = '/callView';
  static const String galleryView = '/galleryView';
  static const String contactView = '/contactView';
  static const String childView = '/childView';
  static const String settingsView = '/settingsView';
  static const String profileView = '/profileView';
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
      case AppRoutesName.contactView:
        return MaterialPageRoute(builder: (_) => ContactsPage());
      case AppRoutesName.forgotPasswordView:
        return MaterialPageRoute(builder: (_) => ForgotPasswordView());
      case AppRoutesName.splashView:
        return MaterialPageRoute(builder: (_) => SplashView());
      case AppRoutesName.otpVerificationView:
        final otpArgs = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) =>
              OtpVerificationView(email: otpArgs?['email'] as String? ?? ''),
        );
      case AppRoutesName.resetPasswordView:
        final resetArgs = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ResetPasswordView(
            email: resetArgs?['email'] as String? ?? '',
            otp: resetArgs?['otp'] as String? ?? '',
          ),
        );
      case AppRoutesName.homeView:
        final shellArgs = settings.arguments as Map<String, dynamic>?;
        final initialIndex = shellArgs?['initialIndex'] as int? ?? 0;
        return MaterialPageRoute(
          builder: (_) => MainShell(initialIndex: initialIndex),
        );
      case AppRoutesName.childView:
        return MaterialPageRoute(builder: (_) => const ChildView());
      case AppRoutesName.settingsView:
        return MaterialPageRoute(builder: (_) => const SettingsView());
      case AppRoutesName.profileView:
        return MaterialPageRoute(builder: (_) => const ProfileView());
      case AppRoutesName.smsView:
        return MaterialPageRoute(builder: (_) => SmsScreen());
      case AppRoutesName.galleryView:
        return MaterialPageRoute(builder: (_) => GalleryScreen());
      case AppRoutesName.callView:
        return MaterialPageRoute(builder: (_) => AccessCallsScreen());
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found!'))),
        );
    }
  }
}
