import 'package:flutter/material.dart';
import 'package:vigil_parents_app/features/gallery/models/galleryChild_model.dart';
import 'package:vigil_parents_app/features/gallery/models/gallery_model.dart';
import 'package:vigil_parents_app/features/gallery/models/gallery_state_model.dart';

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

  Future<List<GalleryPhotoModel>> getRecentPhotos() async => dummyPhotos;
  Future<List<GalleryPhotoModel>> getTodayPhotos() async => dummyPhotos;
  Future<List<GalleryPhotoModel>> getYesterdayPhotos() async => dummyPhotos;

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

/// =======================================================
/// PRO BACK BUTTON
/// =======================================================

class ProBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const ProBackButton({
    super.key,
    this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: iconColor ?? const Color(0xFF1A1A2E),
        ),
      ),
    );
  }
}

/// =======================================================
/// GALLERY APP BAR (SliverAppBar-compatible header)
/// =======================================================

class GalleryAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  const GalleryAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFF7F8FC),
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ProBackButton(onTap: onBack),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }
}

/// =======================================================
/// HEADER  (keeps child info below the app bar)
/// =======================================================

class GalleryHeader extends StatelessWidget {
  final GalleryChildModel child;

  const GalleryHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(child.image),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF82),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${child.name}'s Gallery",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'View photos shared by school',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8E9BB5),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// =======================================================
/// STATS CARD
/// =======================================================

class GalleryStatsCard extends StatelessWidget {
  final GalleryStatsModel stats;

  const GalleryStatsCard({super.key, required this.stats});

  Widget _item(String title, int value, IconData icon, Color accent) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8E9BB5)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _item(
            'Photos',
            stats.totalPhotos,
            Icons.image_outlined,
            const Color(0xFF5B8AF5),
          ),
          _item(
            'Favorites',
            stats.favorites,
            Icons.favorite_border,
            const Color(0xFFEF6C6C),
          ),
          _item(
            'Trips',
            stats.trips,
            Icons.location_on_outlined,
            const Color(0xFF4CAF82),
          ),
          _item(
            'Events',
            stats.events,
            Icons.event_outlined,
            const Color(0xFFF5A623),
          ),
        ],
      ),
    );
  }
}

/// =======================================================
/// RECENT PHOTOS
/// =======================================================

class RecentPhotosSection extends StatelessWidget {
  final List<GalleryPhotoModel> photos;

  const RecentPhotosSection({super.key, required this.photos});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Recent Photos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const Spacer(),
            Text(
              'See all',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5B8AF5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              final photo = photos[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  photo.image,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// =======================================================
/// PHOTO GRID
/// =======================================================

class GalleryPhotoGrid extends StatelessWidget {
  final List<GalleryPhotoModel> photos;

  const GalleryPhotoGrid({super.key, required this.photos});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: .82,
      ),
      itemBuilder: (_, index) {
        final photo = photos[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      photo.image,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        photo.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 14,
                        color: photo.isFavorite
                            ? const Color(0xFFEF6C6C)
                            : const Color(0xFF8E9BB5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              photo.time,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// =======================================================
/// BOTTOM NAV
/// =======================================================

class GalleryBottomNav extends StatelessWidget {
  const GalleryBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 1,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF5B8AF5),
      unselectedItemColor: const Color(0xFF8E9BB5),
      backgroundColor: Colors.white,
      elevation: 0,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.photo_library_outlined),
          label: 'Gallery',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_none),
          label: 'Alerts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          label: 'Reports',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'More'),
      ],
    );
  }
}

/// =======================================================
/// EXAMPLE SCREEN USAGE
/// =======================================================

/// Use GalleryAppBar as the appBar of your Scaffold:
///
/// Scaffold(
///   backgroundColor: const Color(0xFFF7F8FC),
///   appBar: GalleryAppBar(
///     title: "Gallery",
///     onBack: () => Navigator.of(context).pop(),
///     actions: [
///       IconButton(
///         icon: const Icon(Icons.search, color: Color(0xFF1A1A2E)),
///         onPressed: () {},
///       ),
///     ],
///   ),
///   body: SingleChildScrollView(...),
///   bottomNavigationBar: const GalleryBottomNav(),
/// )
