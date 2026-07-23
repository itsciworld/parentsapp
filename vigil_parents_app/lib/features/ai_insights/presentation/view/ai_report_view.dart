import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/features/ai_insights/presentation/view_model/ai_insights_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';

/// In-app viewer for the daily AI report PDF
/// (GET /api/ai/children/{childId}/daily/{date}/report). The PDF is fetched
/// once, shown inline, and the download action saves the same bytes to the
/// device (Downloads on Android, Files on iOS).
class AiReportView extends ConsumerStatefulWidget {
  const AiReportView({super.key});

  @override
  ConsumerState<AiReportView> createState() => _AiReportViewState();
}

class _AiReportViewState extends ConsumerState<AiReportView> {
  /// Saves into the phone's public Downloads folder on Android (MediaStore),
  /// so the report shows up in the Files/Downloads app.
  static const _downloadsChannel = MethodChannel('vigil/downloads');

  Uint8List? _bytes;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bytes =
          await ref.read(aiInsightsViewModelProvider).fetchReport();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _download() async {
    final bytes = _bytes;
    if (bytes == null || _saving) return;

    setState(() => _saving = true);
    try {
      final vm = ref.read(aiInsightsViewModelProvider);
      final childName =
          ref.read(selectedChildProvider).selected?.name.trim() ?? '';
      final safeName = childName.isEmpty
          ? 'vigil_ai_report_${vm.date}'
          : 'vigil_ai_report_${childName.replaceAll(RegExp(r'\s+'), '_')}_${vm.date}';

      final String location;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Native MediaStore save → lands in the public Downloads folder.
        final path = await _downloadsChannel.invokeMethod<String>(
          'saveToDownloads',
          {
            'name': '$safeName.pdf',
            'mimeType': 'application/pdf',
            'bytes': bytes,
          },
        );
        location = path ?? 'Downloads/$safeName.pdf';
      } else {
        // iOS & others: app documents, reachable from the Files app.
        // On web this triggers a normal browser download.
        final path = await FileSaver.instance.saveFile(
          name: safeName,
          bytes: bytes,
          ext: 'pdf',
          mimeType: MimeType.pdf,
        );
        location = path.isEmpty ? '$safeName.pdf' : path;
      }

      if (!mounted) return;
      showAppToast(
        context: context,
        title: 'Report downloaded',
        subtitle: 'Saved to $location',
        type: ToastType.success,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      showAppToast(
        context: context,
        title: 'Download failed',
        subtitle: e.message ?? 'Could not save the report',
        type: ToastType.error,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context: context,
        title: 'Download failed',
        subtitle: e.toString().replaceAll('Exception: ', ''),
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(aiInsightsViewModelProvider).date;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: AppColors.headerTop,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textOnDark),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily AI Report',
              style: TextStyle(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              date,
              style: const TextStyle(
                color: AppColors.textOnDarkMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        actions: [
          if (_bytes != null)
            _saving
                ? const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnDark,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    onPressed: _download,
                    tooltip: 'Download PDF',
                    icon: const Icon(
                      Icons.download_rounded,
                      color: AppColors.textOnDark,
                    ),
                  ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _ReportShimmer();

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.picture_as_pdf_rounded,
                size: 56,
                color: AppColors.alert,
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to load the report',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: _fetch,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return SfPdfViewer.memory(
      _bytes!,
      canShowScrollHead: true,
      canShowPaginationDialog: true,
    );
  }
}

/// Shimmer placeholder shaped like a document page while the PDF downloads.
class _ReportShimmer extends StatelessWidget {
  const _ReportShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 180,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
