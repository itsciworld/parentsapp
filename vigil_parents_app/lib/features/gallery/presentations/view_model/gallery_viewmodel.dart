import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/features/gallery/models/gallery_child_model.dart';
import 'package:vigil_parents_app/features/gallery/models/gallery_model.dart';
import 'package:vigil_parents_app/features/gallery/models/gallery_state_model.dart';
import 'package:vigil_parents_app/features/gallery/repo/gallery_repo.dart';

class GalleryViewModel {
  final GalleryRepository repository;

  GalleryViewModel(this.repository);

  late GalleryChildModel child;
  late GalleryStatsModel stats;

  List<GalleryPhotoModel> recentPhotos = [];
  List<GalleryPhotoModel> todayPhotos = [];
  List<GalleryPhotoModel> yesterdayPhotos = [];

  Future<GalleryViewModel> load() async {
    child = await repository.getChild();
    stats = await repository.getStats();

    recentPhotos = await repository.getRecentPhotos();
    todayPhotos = await repository.getTodayPhotos();
    yesterdayPhotos = await repository.getYesterdayPhotos();

    return this;
  }
}

final galleryViewModelProvider = FutureProvider(
  (ref) => GalleryViewModel(ref.read(galleryRepositoryProvider)).load(),
);
