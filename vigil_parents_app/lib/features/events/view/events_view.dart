import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vigil_parents_app/core/services/background/sync_signals.dart';
import 'package:vigil_parents_app/core/utils/polling_screen.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/components/app_bottom_nav.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/components/app_shimmer.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/child/models/child_permissions_model.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/child_permissions_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/no_child_linked_view.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/permission_denied_view.dart';
import 'package:vigil_parents_app/features/events/models/event_model.dart';
import 'package:vigil_parents_app/features/events/view_model/events_viewmodel.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen>
    with WidgetsBindingObserver, PollingScreen<EventsScreen> {
  /// The calendar date the user tapped. Null until they pick one (then we fall
  /// back to the focus date for the initial highlight).
  DateTime? _selectedDay;

  @override
  Duration get pollInterval => const Duration(minutes: 30);

  @override
  String? get pollFeature => SyncFeature.events;

  @override
  void onPoll() => ref.read(eventsViewModelProvider).refresh();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(selectedChildProvider).load();
      if (!mounted) return;
      ref.read(eventsViewModelProvider).loadEvents();
      final id = ref.read(selectedChildProvider).selectedId;
      if (id != null) ref.read(childPermissionsProvider).ensureLoadedFor(id);
    });

    startPolling();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  void _onChildSelected(String childId) {
    setState(() => _selectedDay = null);
    ref.read(eventsViewModelProvider).reload();
    ref.read(childPermissionsProvider).load(childId);
  }

  void _openDetail(EventModel event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventDetailSheet(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(eventsViewModelProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final size = MediaQuery.of(context).size;

    final noChild = selectedChild.initialized && selectedChild.children.isEmpty;

    // Calendar sharing is switched off on the child's device.
    final permsVm = ref.watch(childPermissionsProvider);
    final denied = permsVm.isDenied(
      selectedChild.selectedId,
      ChildFeature.calendar,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              const AppHeader(showBack: true),
              const SizedBox(height: 12),

              if (noChild)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: NoChildLinkedView(
                        refreshing: selectedChild.loading,
                        onRefresh: () =>
                            ref.read(selectedChildProvider).load(force: true),
                      ),
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Events',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      child: ChildSelectorDropdown(onChanged: _onChildSelected),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (denied)
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => ref
                          .read(childPermissionsProvider)
                          .load(selectedChild.selectedId!),
                      child: PermissionDeniedBody(
                        feature: ChildFeature.calendar,
                        childName: selectedChild.selected?.name,
                        refreshing: permsVm.loading,
                        onRefresh: () => ref
                            .read(childPermissionsProvider)
                            .load(selectedChild.selectedId!),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: vm.refresh,
                      color: AppColors.primary,
                      child: _buildBody(vm, size),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(EventsViewModel vm, Size size) {
    if (vm.loading && vm.allEvents.isEmpty) {
      return const EventsShimmer();
    }

    if (vm.error != null && vm.allEvents.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: size.height * 0.16),
          const Icon(
            Icons.cloud_off_rounded,
            size: 52,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              vm.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Pull down to retry',
              style: TextStyle(color: Colors.black38, fontSize: 12),
            ),
          ),
        ],
      );
    }

    final visible = vm.sortedEvents;
    // Open on — and highlight — today by default; tapping any day overrides it.
    final now = DateTime.now();
    final selectedDay = _selectedDay ?? DateTime(now.year, now.month, now.day);
    final dayEvents = vm.eventsOn(selectedDay);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Calendar card (just markers; tap a day to list its events) ────
        SliverToBoxAdapter(
          child: _CalendarCard(
            events: vm.allEvents,
            selectedDate: selectedDay,
            onDateSelected: (d) => setState(() => _selectedDay = d),
          ),
        ),

        // ── Selected day's events (in the page scroll, no inner scroll) ───
        SliverToBoxAdapter(
          child: _SelectedDayHeader(day: selectedDay, count: dayEvents.length),
        ),
        if (dayEvents.isEmpty)
          const SliverToBoxAdapter(child: _NoEventsOnDay())
        else
          SliverList.separated(
            itemCount: dayEvents.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _DayEventTile(
              event: dayEvents[i],
              onTap: () => _openDetail(dayEvents[i]),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),

        // ── All-events list header ───────────────────────────────────────
        SliverToBoxAdapter(child: _ListHeader(count: visible.length)),

        if (visible.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                children: const [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 52,
                    color: Colors.black26,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No events to show',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList.separated(
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _Reveal(
              // Stagger the first handful of items, then render instantly.
              delayMs: index < 8 ? index * 55 : 0,
              child: _EventCard(
                event: visible[index],
                onTap: () => _openDetail(visible[index]),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────────
///  CATEGORY VISUALS
/// ──────────────────────────────────────────────────────────────────────────
Color _categoryColor(EventCategory c) => switch (c) {
  EventCategory.meeting => AppColors.blueIcon,
  EventCategory.holiday => AppColors.alert,
  EventCategory.observance => AppColors.warning,
  EventCategory.general => AppColors.primary,
};

IconData _categoryIcon(EventCategory c) => switch (c) {
  EventCategory.meeting => Icons.videocam_rounded,
  EventCategory.holiday => Icons.celebration_rounded,
  EventCategory.observance => Icons.event_note_rounded,
  EventCategory.general => Icons.event_rounded,
};

String _categoryLabel(EventCategory c) => switch (c) {
  EventCategory.meeting => 'Meeting',
  EventCategory.holiday => 'Holiday',
  EventCategory.observance => 'Observance',
  EventCategory.general => 'Event',
};

/// ──────────────────────────────────────────────────────────────────────────
///  CALENDAR
/// ──────────────────────────────────────────────────────────────────────────
class _CalendarCard extends StatefulWidget {
  final List<EventModel> events;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _CalendarCard({
    required this.events,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<_CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<_CalendarCard> {
  late _EventDataSource _dataSource = _EventDataSource(widget.events);

  @override
  void didUpdateWidget(_CalendarCard old) {
    super.didUpdateWidget(old);
    // Rebuild the data source whenever the events list reference OR length
    // changes. The old logic used && which prevented rebuilds when a refresh
    // returned the same count of events, causing stale indicator dots.
    if (!identical(old.events, widget.events) ||
        old.events.length != widget.events.length) {
      _dataSource = _EventDataSource(widget.events);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.blueIcon,
                  Color(0xFF7C3AED),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 370,
            child: SfCalendar(
              view: CalendarView.month,
              dataSource: _dataSource,
              initialDisplayDate: widget.selectedDate ?? DateTime.now(),
              initialSelectedDate: widget.selectedDate ?? DateTime.now(),
              showNavigationArrow: true,
              showDatePickerButton: true,
              showTodayButton: true,
              cellBorderColor: Colors.transparent,
              todayHighlightColor: AppColors.primary,
              selectionDecoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              headerHeight: 50,
              headerStyle: CalendarHeaderStyle(
                textAlign: TextAlign.center,
                backgroundColor: AppColors.scaffold.withValues(alpha: 0.5),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              viewHeaderStyle: ViewHeaderStyle(
                backgroundColor: Colors.white,
                dayTextStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
              monthViewSettings: MonthViewSettings(
                appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
                showAgenda: false,
                numberOfWeeksInView: 6,
                appointmentDisplayCount: 4,
                monthCellStyle: MonthCellStyle(
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  trailingDatesTextStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                  leadingDatesTextStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                ),
              ),
              onTap: (details) {
                if (details.targetElement == CalendarElement.calendarCell &&
                    details.date != null) {
                  widget.onDateSelected(details.date!);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bridges [EventModel]s into Syncfusion's calendar appointment API.
class _EventDataSource extends CalendarDataSource {
  _EventDataSource(List<EventModel> source) {
    appointments = source;
  }

  EventModel _event(int index) => appointments![index] as EventModel;

  @override
  DateTime getStartTime(int index) => _event(index).start;

  @override
  DateTime getEndTime(int index) =>
      _event(index).end ?? _event(index).start.add(const Duration(hours: 1));

  @override
  String getSubject(int index) => _event(index).displayTitle;

  @override
  bool isAllDay(int index) => _event(index).isAllDay;

  @override
  Color getColor(int index) => _categoryColor(_event(index).category);
}

/// ──────────────────────────────────────────────────────────────────────────
///  LIST HEADER
/// ──────────────────────────────────────────────────────────────────────────
class _ListHeader extends StatelessWidget {
  final int count;

  const _ListHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.blueIcon],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Text(
            'All Events',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────────
///  SELECTED-DAY SECTION
/// ──────────────────────────────────────────────────────────────────────────
class _SelectedDayHeader extends StatelessWidget {
  final DateTime day;
  final int count;

  const _SelectedDayHeader({required this.day, required this.count});

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekDay = weekDays[(day.weekday - 1) % 7];
    final label = '$weekDay, ${day.day} ${months[day.month - 1]} ${day.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.blueIcon.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: count > 0
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.textSecondary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count > 0 ? '$count event${count > 1 ? 's' : ''}' : 'No events',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: count > 0 ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoEventsOnDay extends StatelessWidget {
  const _NoEventsOnDay();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 28,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'No events scheduled',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black38,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'This day is free',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black26),
          ),
        ],
      ),
    );
  }
}

/// Compact row for a single event on the selected day. Smaller than the full
/// [_EventCard] so a few of them fit without any cramped inner scroll.
class _DayEventTile extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;

  const _DayEventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(event.category);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Main tile content
            Container(
              padding: const EdgeInsets.only(
                left: 18,
                right: 14,
                top: 12,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.cardBorder.withValues(alpha: 0.7),
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _categoryIcon(event.category),
                      size: 15,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (event.hasLocation) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.place_rounded,
                                size: 11,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  event.location!.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.isAllDay ? 'All day' : event.formattedTime,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Left accent bar (painted on top to avoid non-uniform border)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────────
///  EVENT CARD
/// ──────────────────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;

  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = _categoryColor(event.category);
    final summary = event.summary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date badge (accent-tinted by category)
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    event.start.day.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _monthShort(event.start.month),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CategoryChip(category: event.category),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        event.isAllDay
                            ? Icons.event_available_rounded
                            : Icons.schedule_rounded,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.isAllDay ? 'All day' : event.formattedRange,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (event.hasLocation) ...[
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.place_rounded,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _monthShort(int m) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[(m - 1) % 12];
  }
}

/// Small pill showing the event category (Meeting / Holiday / ...).
class _CategoryChip extends StatelessWidget {
  final EventCategory category;

  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_categoryIcon(category), size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            _categoryLabel(category),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────────
///  DETAIL SHEET
/// ──────────────────────────────────────────────────────────────────────────
class _EventDetailSheet extends StatelessWidget {
  final EventModel event;

  const _EventDetailSheet({required this.event});

  Future<void> _joinMeet(BuildContext context) async {
    final link = event.meetLink;
    if (link == null) return;
    final uri = Uri.tryParse(link);
    final ok =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppToast(
        context: context,
        title: 'Could not open',
        subtitle: 'No app available to open the meeting link.',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(event.category);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_categoryIcon(event.category), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.displayTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _CategoryChip(category: event.category),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _DetailRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: event.formattedDate,
          ),
          _DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Time',
            value: event.formattedRange,
          ),
          if (event.hasLocation)
            _DetailRow(
              icon: Icons.place_rounded,
              label: 'Location',
              value: event.location!.trim(),
            ),
          if (event.hasDescription)
            _DetailRow(
              icon: Icons.notes_rounded,
              label: 'Details',
              value: event.cleanDescription,
            ),
          if (event.isOnlineMeeting) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blueIcon,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _joinMeet(context),
                icon: const Icon(Icons.videocam_rounded, size: 18),
                label: const Text(
                  'Join Google Meet',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade + slide-up entrance, mirroring the home screen's reveal animation.
class _Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _Reveal({required this.child, this.delayMs = 0});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    if (widget.delayMs == 0) {
      _c.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 22),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
