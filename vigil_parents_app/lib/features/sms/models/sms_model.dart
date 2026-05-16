class SmsModel {
  final String name;
  final String phone;
  final String message;
  final String time;
  final String image;
  final bool isSent;
  final bool isUnknown;
  final bool isMedia;
  final bool isVoice;

  SmsModel({
    required this.name,
    required this.phone,
    required this.message,
    required this.time,
    required this.image,
    this.isSent = false,
    this.isUnknown = false,
    this.isMedia = false,
    this.isVoice = false,
  });
}
