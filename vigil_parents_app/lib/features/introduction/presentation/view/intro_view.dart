import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:vigil_parents_app/core/appColor/app_theme/app_gradient.dart';
import 'package:vigil_parents_app/core/routing/routes.dart';
import 'package:vigil_parents_app/features/introduction/models/itro_model.dart';
import 'package:vigil_parents_app/features/introduction/presentation/view_model/intro_viewmodel.dart';
import 'package:vigil_parents_app/globle_components/custom_button/custombutton.dart';

class IntroView extends StatefulWidget {
  const IntroView({super.key});

  @override
  State<IntroView> createState() => _IntroViewState();
}

class _IntroViewState extends State<IntroView> {
  final IntroViewModel _viewModel = IntroViewModel();
  final introKey = GlobalKey<IntroductionScreenState>();

  void _onIntroEnd(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(AppRoutesName.loginView);
  }

  Widget _buildDescription(IntroFeatureModel feature) {
    if (feature.bulletPoints == null || feature.bulletPoints!.isEmpty) {
      return Text(feature.description, style: const TextStyle(fontSize: 16));
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(feature.description, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: feature.bulletPoints!.map<Widget>((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6.0),
                      child: Icon(Icons.circle, size: 8, color: Colors.black),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item, style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageDecoration = PageDecoration(
      titleTextStyle: const TextStyle(
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
      ),
      bodyTextStyle: const TextStyle(fontSize: 16.0),
      bodyPadding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Colors.transparent,
      imagePadding: EdgeInsets.zero,
      bodyAlignment: Alignment.centerLeft,
      titlePadding: const EdgeInsets.only(bottom: 16),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE0F7FA), // Light cyan color
              Color(0xFFFFFFFF), // White color
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: IntroductionScreen(
                  key: introKey,
                  globalBackgroundColor: Colors.transparent,
                  pages: _viewModel.features.map((feature) {
                    return PageViewModel(
                      titleWidget: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          feature.title,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      bodyWidget: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildDescription(feature),
                      ),
                      decoration: pageDecoration,
                    );
                  }).toList(),
                  onDone: () => _onIntroEnd(context),
                  onSkip: () => _onIntroEnd(context),
                  showSkipButton: true,
                  skipOrBackFlex: 0,
                  nextFlex: 0,
                  showBackButton: false,
                  back: const Icon(Icons.arrow_back),
                  skip: const Text(
                    'Skip',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  next: const Icon(Icons.arrow_forward, color: Colors.black),
                  done: const Text(
                    'Done',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  curve: Curves.fastLinearToSlowEaseIn,
                  controlsMargin: const EdgeInsets.all(16),
                  controlsPadding: const EdgeInsets.fromLTRB(
                    8.0,
                    4.0,
                    8.0,
                    4.0,
                  ),
                  dotsDecorator: const DotsDecorator(
                    size: Size(12.0, 12.0),
                    color: Colors.grey,
                    activeSize: Size(12.0, 12.0),
                    activeColor: Colors.blue,
                    activeShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25.0)),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 42.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomButton(
                      onTap: () {
                        // Replace intro so login becomes the root — pressing
                        // back from login exits the app instead of returning
                        // to the intro carousel.
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutesName.loginView,
                        );
                      },
                      isLoading: false,
                      label: 'Login',

                      gradient: AppGradients.primaryButton,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutesName.signupView);
                      },
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
