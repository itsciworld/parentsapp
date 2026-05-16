import '../models/sms_model.dart';

class SmsRepository {
  Future<List<SmsModel>> fetchMessages() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      SmsModel(
        name: "Rohit Verma",
        phone: "+91 98765 43210",
        message: "Bro, are we meeting at the cafe today?",
        time: "10:45 AM",
        image: "https://i.pravatar.cc/150?img=11",
        isSent: true,
      ),
      SmsModel(
        name: "Ananya Singh",
        phone: "+91 91234 56789",
        message: "Sure, I’ll be there by 5.",
        time: "10:32 AM",
        image: "https://i.pravatar.cc/150?img=32",
      ),
      SmsModel(
        name: "Unknown Number",
        phone: "+91 99887 76655",
        message: "Hey, can you share your location?",
        time: "09:58 AM",
        image: "https://i.pravatar.cc/150?img=52",
        isUnknown: true,
      ),
      SmsModel(
        name: "Rohit Verma",
        phone: "+91 98765 43210",
        message: "",
        time: "09:15 AM",
        image: "https://picsum.photos/200",
        isMedia: true,
        isSent: true,
      ),
      SmsModel(
        name: "Ananya Singh",
        phone: "+91 91234 56789",
        message: "",
        time: "08:47 AM",
        image: "https://i.pravatar.cc/150?img=32",
        isVoice: true,
      ),
    ];
  }
}
