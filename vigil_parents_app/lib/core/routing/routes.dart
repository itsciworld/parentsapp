import 'package:flutter/material.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/forgot_pass.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/login_view.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/otp_verification.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/signup.dart';
import 'package:vigil_parents_app/features/auth/presentation/view/splash_view.dart';
import 'package:vigil_parents_app/features/calls/presentation/view_model/view/calls_view.dart';
import 'package:vigil_parents_app/features/contact/view/contact_view.dart';
import 'package:vigil_parents_app/features/gallery/presentations/view/gallery_view.dart';
import 'package:vigil_parents_app/features/home/presentation/view/home_view.dart';
import 'package:vigil_parents_app/features/introduction/presentation/view/intro_view.dart';
import 'package:vigil_parents_app/features/sms/view/sms_view.dart';

class AppRoutesName {
  static const String introView = '/introView';
  static const String loginView = '/loginView';
  static const String signupView = '/signupView';
  static const String forgotPasswordView = '/forgotPasswordView';
  static const String splashView = '/splashView';
  static const String otpVerificationView = '/otpVerificationView';
  static const String homeView = '/homeView';
  static const String smsView = '/smsView';
  static const String callView = '/callView';
  static const String galleryView = '/galleryView';
  static const String contactView = '/contactView';
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
        return MaterialPageRoute(builder: (_) => OtpVerificationView());
      case AppRoutesName.homeView:
        return MaterialPageRoute(builder: (_) => HomeScreen());
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
