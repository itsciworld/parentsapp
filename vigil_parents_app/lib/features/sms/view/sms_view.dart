import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/features/sms/view_model/sms_viewmodel.dart';
import 'package:vigil_parents_app/features/sms/widgets/message_card.dart';
import 'package:vigil_parents_app/features/sms/widgets/sms_filterd_cart.dart';
import 'package:vigil_parents_app/features/sms/widgets/sms_header.dart';
import 'package:vigil_parents_app/features/sms/widgets/sms_state_card.dart';

class SmsScreen extends ConsumerStatefulWidget {
  const SmsScreen({super.key});

  @override
  ConsumerState<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends ConsumerState<SmsScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(smsViewModelProvider).loadMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(smsViewModelProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      // bottomNavigationBar: const BottomNavbar(),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              const SmsHeader(),

              const SizedBox(height: 20),

              /// SEARCH + FILTER
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search messages or contacts...",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),
                ],
              ),

              const SizedBox(height: 18),

              const FilterTabs(),

              const SizedBox(height: 18),

              SmsStateCard(),

              const SizedBox(height: 18),

              Expanded(
                child: vm.loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: vm.messages.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (_, index) {
                          return MessageCard(
                            model: vm.messages[index],
                            width: size.width,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
