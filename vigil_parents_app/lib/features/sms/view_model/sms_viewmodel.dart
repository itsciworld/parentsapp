import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/sms/models/sms_model.dart';
import 'package:vigil_parents_app/features/sms/repo/sms_repo.dart';

class SmsViewModel extends ChangeNotifier {
  final SmsRepository repository;

  SmsViewModel(this.repository);

  List<SmsModel> messages = [];

  bool loading = false;

  Future<void> loadMessages() async {
    loading = true;
    notifyListeners();

    messages = await repository.fetchMessages();

    loading = false;
    notifyListeners();
  }
}

final smsViewModelProvider = ChangeNotifierProvider((ref) {
  return SmsViewModel(SmsRepository());
});
