import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/features/gallery/models/galleryChild_model.dart';

import 'package:vigil_parents_app/features/gallery/models/gallery_model.dart';
import 'package:vigil_parents_app/features/gallery/models/gallery_state_model.dart';

/// =======================================================
/// REPOSITORY
/// =======================================================

abstract class GalleryRepository {
  Future<GalleryChildModel> getChild();

  Future<List<GalleryPhotoModel>> getRecentPhotos();

  Future<List<GalleryPhotoModel>> getTodayPhotos();

  Future<List<GalleryPhotoModel>> getYesterdayPhotos();

  Future<GalleryStatsModel> getStats();
}

/// =======================================================
/// LOCAL SOURCE
/// =======================================================

class GalleryLocalSource {
  Future<GalleryChildModel> getChild() async {
    return GalleryChildModel(
      id: '1',
      name: 'Aarav Sharma',
      image: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
    );
  }

  Future<List<GalleryPhotoModel>> getRecentPhotos() async {
    return dummyPhotos;
  }

  Future<List<GalleryPhotoModel>> getTodayPhotos() async {
    return dummyPhotos;
  }

  Future<List<GalleryPhotoModel>> getYesterdayPhotos() async {
    return dummyPhotos;
  }

  Future<GalleryStatsModel> getStats() async {
    return GalleryStatsModel(
      totalPhotos: 120,
      favorites: 20,
      trips: 5,
      events: 7,
    );
  }
}

/// =======================================================
/// REPOSITORY IMPL
/// =======================================================

class GalleryRepositoryImpl implements GalleryRepository {
  GalleryRepositoryImpl(this.localSource);

  final GalleryLocalSource localSource;

  @override
  Future<GalleryChildModel> getChild() {
    return localSource.getChild();
  }

  @override
  Future<List<GalleryPhotoModel>> getRecentPhotos() {
    return localSource.getRecentPhotos();
  }

  @override
  Future<List<GalleryPhotoModel>> getTodayPhotos() {
    return localSource.getTodayPhotos();
  }

  @override
  Future<List<GalleryPhotoModel>> getYesterdayPhotos() {
    return localSource.getYesterdayPhotos();
  }

  @override
  Future<GalleryStatsModel> getStats() {
    return localSource.getStats();
  }
}

/// =======================================================
/// PROVIDER
/// =======================================================

final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepositoryImpl(GalleryLocalSource());
});

/// =======================================================
/// DUMMY DATA
/// =======================================================

final List<GalleryPhotoModel> dummyPhotos = [
  GalleryPhotoModel(
    id: '1',
    image: 'https://images.unsplash.com/photo-1517841905240-472988babdf9',
    time: '10:15 AM',
    isFavorite: true,
  ),
  GalleryPhotoModel(
    id: '2',
    image: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb',
    time: '09:52 AM',
    isFavorite: false,
  ),
  GalleryPhotoModel(
    id: '3',
    image: 'https://images.unsplash.com/photo-1517849845537-4d257902454a',
    time: '09:30 AM',
    isFavorite: true,
  ),
  GalleryPhotoModel(
    id: '4',
    image: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
    time: '08:47 AM',
    isFavorite: false,
  ),
];
