import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/features/child/models/child_model.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/child_viewmodel.dart';

class ChildView extends ConsumerStatefulWidget {
  const ChildView({super.key});

  @override
  ConsumerState<ChildView> createState() => _ChildViewState();
}

class _ChildViewState extends ConsumerState<ChildView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(childViewModelProvider).loadChildren();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(childViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: AppColors.headerTop,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'My Children',
          style: TextStyle(
            color: AppColors.textOnDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textOnDark),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: vm.refresh,
        child: _buildBody(vm),
      ),
    );
  }

  Widget _buildBody(ChildViewModel vm) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.hasError) {
      return _ErrorState(
        message: vm.errorMessage ?? 'Something went wrong',
        onRetry: () => vm.loadChildren(),
      );
    }

    if (vm.isEmpty) {
      return const _EmptyState();
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: vm.children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final c = vm.children[i];
        return _ChildCard(
          child: c,
          isDeleting: vm.isDeleting(c.id),
          isUpdating: vm.isUpdating(c.id),
          onDelete: () => _confirmAndDelete(vm, c),
          onEdit: () => _editName(vm, c),
        );
      },
    );
  }

  Future<void> _confirmAndDelete(ChildViewModel vm, ChildModel child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete child?'),
        content: Text(
          'Are you sure you want to delete ${child.name.isEmpty ? "this child" : child.name}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.alert),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final msg = await vm.deleteChild(child.id);
      if (!mounted) return;
      showAppToast(
        context: context,
        title: 'Deleted',
        subtitle: msg,
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context: context,
        title: 'Delete failed',
        subtitle: e.toString().replaceAll('Exception: ', ''),
        type: ToastType.error,
      );
    }
  }

  Future<void> _editName(ChildViewModel vm, ChildModel child) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initialName: child.name),
    );

    if (newName == null || !mounted) return;
    if (newName == child.name.trim()) return;

    try {
      await vm.updateChildName(child.id, newName);
      if (!mounted) return;
      showAppToast(
        context: context,
        title: 'Updated',
        subtitle: 'Child name updated successfully',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context: context,
        title: 'Update failed',
        subtitle: e.toString().replaceAll('Exception: ', ''),
        type: ToastType.error,
      );
    }
  }
}

/// Dialog that owns its own [TextEditingController] so the controller's
/// lifecycle is tied to the dialog (avoids "used after disposed" errors).
class _EditNameDialog extends StatefulWidget {
  final String initialName;

  const _EditNameDialog({required this.initialName});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit child name'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter child name',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Name cannot be empty';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ChildCard extends StatelessWidget {
  final ChildModel child;
  final bool isDeleting;
  final bool isUpdating;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ChildCard({
    required this.child,
    required this.isDeleting,
    required this.isUpdating,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFor(child.name);
    final isActive = child.status.toLowerCase() == 'active';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with online dot
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: child.isOnline ? AppColors.online : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Name / age / device
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name.isEmpty ? 'Unnamed' : child.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Age ${child.age}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_android_rounded,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        child.deviceName.isEmpty
                            ? 'No device linked'
                            : child.deviceName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status + delete
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.greenSoft : AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'Active' : child.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: isUpdating
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : IconButton(
                            padding: EdgeInsets.zero,
                            splashRadius: 18,
                            onPressed: onEdit,
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: AppColors.primary,
                              size: 21,
                            ),
                            tooltip: 'Edit name',
                          ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: isDeleting
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.alert,
                            ),
                          )
                        : IconButton(
                            padding: EdgeInsets.zero,
                            splashRadius: 18,
                            onPressed: onDelete,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.alert,
                              size: 22,
                            ),
                            tooltip: 'Delete',
                          ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initialsFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        const Icon(
          Icons.child_care_rounded,
          size: 64,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'No children yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Pull down to refresh',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.alert),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Unable to load children',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
          ),
        ),
      ],
    );
  }
}
