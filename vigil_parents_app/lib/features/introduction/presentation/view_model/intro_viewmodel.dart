import 'package:flutter/material.dart';
import 'package:vigil_parents_app/features/introduction/models/itro_model.dart';

class IntroViewModel extends ChangeNotifier {
  final List<IntroFeatureModel> _features = [
    IntroFeatureModel(
      title: 'Protect Your \nChild',
      description:
          'The digital world offers endless opportunities but also carries risks. \n\n'
          'Reports indicate 500,000 online predators are active daily, and child sexual abuse reports have surged by 87% since 2019. \n\n'
          'Safeguard your child\'s online experience with Vigil1, the ultimate parental monitoring app.',
    ),
    IntroFeatureModel(
      title: 'Key Features',
      description: 'With Vigil1, You Can',
      bulletPoints: [
        'Block harmful apps.',
        'Track time spent on apps and set usage limits.',
        'Keep an eye on their social interactions and activities.',
        'Protect your child from bullies, online predators, and inappropriate content.',
      ],
    ),
    IntroFeatureModel(
      title: 'We Need Your Permission',
      description:
          'To provide comprehensive protection and monitoring, this app will access certain installed applications on your child’s device. \n\n'
          'By using this application, you give us your permission to access and manage these apps to ensure optimal functionality and security. \n\n'
          'Rest assured, your privacy and data security are our top priorities.',
    ),
    IntroFeatureModel(
      title: 'User Agreement',
      description:
          'By continuing to use this app, you agree to abide by our User Agreement, Privacy Policy, and Terms and Conditions. \n\n'
          'These documents outline your rights and responsibilities, as well as how we collect, use, and protect your information. \n\n'
          'Take a moment to review these policies to ensure you understand and agree with them.',
    ),
  ];

  List<IntroFeatureModel> get features => _features;
}
