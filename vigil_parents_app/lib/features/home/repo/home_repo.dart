import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';

abstract class HomeRepository {
  Future<HomeDashboardData> fetchDashboard();
}

/// Dummy implementation — use this until the API is ready.
class DummyHomeRepository implements HomeRepository {
  @override
  Future<HomeDashboardData> fetchDashboard() async {
    // Simulate a network call so loading states are exercised.
    await Future.delayed(const Duration(milliseconds: 600));

    return const HomeDashboardData(
      // The bell's dot is driven by FeatureBadgesViewModel, which counts real
      // unseen notifications for the selected child. A non-zero literal here
      // would light the bell for accounts with no linked child at all.
      notificationCount: 0,
      // Real name comes from the /api/auth/me profile; this is only a
      // placeholder shown while that request is in flight.
      parent: ParentProfile(name: '', initials: ''),
      // Empty by design. These fields are only ever fallbacks for the selected
      // child's real values, and inventing a name or device here is what made
      // the home screen appear to show another child's data on first load.
      child: ChildProfile(
        name: '',
        avatarUrl: '',
        isOnline: false,
        deviceModel: '',
        osVersion: '',
        lastSync: '—',
      ),
      statusIndicators: [
        StatusIndicator(
          icon: Icons.verified_user_rounded,
          title: 'Device Secure',
          subtitle: 'Protected',
          color: AppColors.primary,
        ),
        StatusIndicator(
          icon: Icons.podcasts_rounded,
          title: 'Monitoring Active',
          subtitle: 'All systems running',
          color: AppColors.primary,
        ),
        StatusIndicator(
          icon: Icons.cloud_done_rounded,
          title: 'Data Sync',
          subtitle: 'Up to date',
          color: AppColors.blueIcon,
        ),
      ],
      features: [
        FeatureTile(
          id: 'sms',
          title: 'SMS',
          subtitle: 'View SMS & texts',
          icon: Icons.sms_rounded,
          iconColor: AppColors.greenIcon,
          iconBackground: AppColors.greenSoft,
        ),
        // Gallery — temporarily hidden from the monitoring tools grid.
        FeatureTile(
          id: 'gallery',
          title: 'Gallery',
          subtitle: 'Photos & videos',
          icon: Icons.photo_library_rounded,
          iconColor: AppColors.orangeIcon,
          iconBackground: AppColors.orangeSoft,
        ),

        // FeatureTile(
        //   id: 'whatsapp',
        //   title: 'WhatsApp Messages',
        //   subtitle: 'View WA chats',
        //   icon: Icons.message_rounded,
        //   iconColor: AppColors.whatsappIcon,
        //   iconBackground: AppColors.whatsappSoft,
        //   badgeCount: 18,
        // ),
        FeatureTile(
          id: 'calls',
          title: 'Calls',
          subtitle: 'Call logs & history',
          icon: Icons.phone_in_talk_rounded,
          iconColor: AppColors.purpleIcon,
          iconBackground: AppColors.purpleSoft,
        ),

        FeatureTile(
          id: 'device_info',
          title: 'Device Info',
          subtitle: 'Battery & network',
          icon: Icons.phonelink_setup_rounded,
          iconColor: AppColors.indigoIcon,
          iconBackground: AppColors.indigoSoft,
        ),

        FeatureTile(
          id: 'Contacts',
          title: 'Contacts',
          subtitle: 'View contacts',
          icon: Icons.contact_page_rounded,
          iconColor: AppColors.orangeIcon,
          iconBackground: AppColors.orangeSoft,
        ),

        FeatureTile(
          id: 'events',
          title: 'Events',
          subtitle: 'Calendar & events',
          icon: Icons.event_rounded,
          iconColor: AppColors.blueIcon,
          iconBackground: AppColors.blueSoft,
        ),

        // FeatureTile(
        //   id: 'social',
        //   title: 'Social Media',
        //   subtitle: 'Monitor activities',
        //   icon: Icons.public_rounded,
        //   iconColor: AppColors.purpleIcon,
        //   iconBackground: AppColors.purpleSoft,
        //   badgeCount: 16,
        //   isLocked: true,

        //   // NOTE: Material Icons has no real brand glyphs for IG/Snap/TikTok,
        //   // so these are stand-ins. REPLACE-LATER with brand SVG/PNG assets
        //   // (e.g. via flutter_svg) for pixel-accurate brand icons.
        //   clusterIcons: [
        //     Icons.camera_alt_rounded, // Instagram stand-in
        //     Icons.facebook, // valid Material icon
        //     Icons.chat_bubble_rounded, // Snapchat stand-in
        //     Icons.music_note_rounded, // TikTok stand-in
        //   ],
        // ),
        // FeatureTile(
        //   id: 'ai',
        //   title: 'AI Insights',
        //   subtitle: 'Smart analysis',
        //   icon: Icons.memory_rounded,
        //   iconColor: AppColors.indigoIcon,
        //   iconBackground: AppColors.indigoSoft,
        //   isLocked: true,
        // ),
      ],
      activity: ActivitySummary(
        screenTime: '3h 45m',
        screenTimeDeltaPercent: 12,
        alertCount: 2,
        sparkline: [0.35, 0.55, 0.30, 0.62, 0.40, 0.70, 0.48, 0.66, 0.52, 0.78],
      ),
      aiInsight: AiInsight(
        title: 'AI Insight',
        message:
            'Harry spent more time on Instagram and YouTube today. Consider '
            'setting screen time limits.',
        isNew: true,
      ),
      foundation: FoundationInfo(
        name: 'MITRA HELP FOUNDATION',
        tagline: 'Together, We Create Safer Tomorrow',
        description:
            'A part of your subscription supports child safety and digital '
            'literacy programs by MITRA HELP FOUNDATION.',
        childrenImpacted: '12,450+',
        awarenessSessions: '320+',
        communitySupporters: '1,250+',
      ),
    );
  }
}
