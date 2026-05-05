class IntroFeatureModel {
  final String title;
  final String description;
  final List<String>? bulletPoints;

  IntroFeatureModel({
    required this.title,
    required this.description,
    this.bulletPoints,
  });
}
