// ══════════════════════════════════════════════════════════════
//  VIEW  –  CATEGORY CHIPS
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/features/contact/contact_repo.dart';
import 'package:vigil_parents_app/features/contact/models/contacts_model.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _repo = ContactsRepository();
  final _searchCtrl = TextEditingController();

  final ContactCategory _activeCategory = ContactCategory.all;
  ContactStatus? _activeStatus; // null = all
  String _searchQuery = '';

  // status tab definitions
  final _statusTabs = const [
    _StatusTab(label: 'All', status: null),
    _StatusTab(label: 'Saved', status: ContactStatus.saved),
    _StatusTab(label: 'Unknown', status: ContactStatus.unknown),
    _StatusTab(label: 'Blocked', status: ContactStatus.blocked),
  ];

  // final _categories = [
  //   ContactCategory.all,
  //   ContactCategory.family,
  //   ContactCategory.friends,
  //   ContactCategory.education,
  //   ContactCategory.unknown,
  // ];

  // String _categoryLabel(ContactCategory c) {
  //   switch (c) {
  //     case ContactCategory.all:
  //       return 'All';
  //     case ContactCategory.family:
  //       return 'Family';
  //     case ContactCategory.friends:
  //       return 'Friends';
  //     case ContactCategory.education:
  //       return 'Education';
  //     case ContactCategory.unknown:
  //       return 'Unknown';
  //   }
  // }

  List<ContactModel> get _filtered => _repo.filter(
    category: _activeCategory,
    status: _activeStatus,
    query: _searchQuery,
  );

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openDetail(ContactModel contact) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContactDetailSheet(contact: contact),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _repo.getStats();
    final contacts = _filtered;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Column(
          children: [
            // ── STICKY HEADER ──
            _Header(
              searchCtrl: _searchCtrl,
              onSearch: (v) => setState(() => _searchQuery = v),
              statusTabs: _statusTabs,
              activeStatus: _activeStatus,
              onStatusTab: (s) => setState(() => _activeStatus = s),
              stats: stats,
            ),

            // ── CATEGORY CHIPS ──
            // _CategoryChips(
            //   categories: _categories,
            //   active: _activeCategory,
            //   label: _categoryLabel,
            //   onSelect: (c) => setState(() => _activeCategory = c),
            // ),

            // ── CONTACT LIST ──
            Expanded(
              child: contacts.isEmpty
                  ? _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: contacts.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        indent: 78,
                        endIndent: 0,
                        color: Color(0xFFF1F3F5),
                      ),
                      itemBuilder: (ctx, i) {
                        final c = contacts[i];
                        return _ContactRow(
                          contact: c,
                          onTap: () => _openDetail(c),
                          isFirst: i == 0,
                          isLast: i == contacts.length - 1,
                        );
                      },
                    ),
            ),
          ],
        ),

        // ── BOTTOM NAV ──
        // bottomNavigationBar: _BottomNav(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW  –  HEADER
// ══════════════════════════════════════════════════════════════

class _StatusTab {
  final String label;
  final ContactStatus? status;
  const _StatusTab({required this.label, required this.status});
}

class _Header extends StatelessWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final List<_StatusTab> statusTabs;
  final ContactStatus? activeStatus;
  final ValueChanged<ContactStatus?> onStatusTab;
  final ContactsStats stats;

  const _Header({
    required this.searchCtrl,
    required this.onSearch,
    required this.statusTabs,
    required this.activeStatus,
    required this.onStatusTab,
    required this.stats,
  });

  static const _navy = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand row
            AppHeader(
              showBack: true,

              // actionIcon: Icons.settings,
              // onActionTap: () {},
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(1, 16, 20, 0),
              child: Row(
                children: [
                  SizedBox(width: 20),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contacts',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Aryan Sharma · ${10} contacts',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFADB5BD),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Stats strip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _StatCard(
                    icon: Icons.people_outline,
                    value: '${stats.total}',
                    label: 'Total',
                    color: _navy,
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    icon: Icons.check_circle_outline,
                    value: '${stats.saved}',
                    label: 'Saved',
                    color: const Color(0xFF2F9E44),
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    icon: Icons.help_outline,
                    value: '${stats.unknown}',
                    label: 'Unknown',
                    color: const Color(0xFFE67700),
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    icon: Icons.block,
                    value: '${stats.blocked}',
                    label: 'Blocked',
                    color: const Color(0xFFC92A2A),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 14, color: _navy),
                  decoration: InputDecoration(
                    hintText: 'Search name or number…',
                    hintStyle: const TextStyle(
                      color: Color(0xFFADB5BD),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFFADB5BD),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Status tabs
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: statusTabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final tab = statusTabs[i];
                  final active = activeStatus == tab.status;
                  return GestureDetector(
                    onTap: () => onStatusTab(tab.status),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: active ? _navy : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? Colors.white
                              : const Color(0xFF868E96),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F3F5)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW  –  STAT CARD
// ══════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFFADB5BD),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW  –  CONTACT ROW
// ══════════════════════════════════════════════════════════════

class _ContactRow extends StatelessWidget {
  final ContactModel contact;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _ContactRow({
    required this.contact,
    required this.onTap,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(20) : Radius.zero,
        bottom: isLast ? const Radius.circular(20) : Radius.zero,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(20) : Radius.zero,
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Avatar
              _ContactAvatar(contact: contact, size: 48),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.phone,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFADB5BD),
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusBadge(status: contact.status),
                        const SizedBox(width: 6),
                        _CategoryBadge(category: contact.category),
                      ],
                    ),
                  ],
                ),
              ),

              // Right side
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    contact.lastSeen,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFADB5BD),
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 13,
                        color: Color(0xFF868E96),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${contact.calls}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF495057),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFCED4DA),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW  –  CONTACT AVATAR
// ══════════════════════════════════════════════════════════════

class _ContactAvatar extends StatelessWidget {
  final ContactModel contact;
  final double size;

  const _ContactAvatar({required this.contact, required this.size});

  @override
  Widget build(BuildContext context) {
    final badgeIcon = contact.status == ContactStatus.unknown
        ? Icons.warning_amber_rounded
        : contact.status == ContactStatus.blocked
        ? Icons.block
        : null;
    final badgeColor = contact.status == ContactStatus.unknown
        ? const Color(0xFFF59F00)
        : const Color(0xFFFA5252);

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: contact.color.withValues(alpha: 0.12),
            border: Border.all(
              color: contact.color.withValues(alpha: .3),
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            contact.initials,
            style: TextStyle(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w800,
              color: contact.color,
            ),
          ),
        ),
        if (badgeIcon != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(badgeIcon, size: 9, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW  –  BADGES
// ══════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final ContactStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final map = {
      ContactStatus.saved: (
        label: 'SAVED',
        bg: const Color(0xFFE8FDF2),
        fg: const Color(0xFF2F9E44),
      ),
      ContactStatus.unknown: (
        label: 'UNKNOWN',
        bg: const Color(0xFFFFF4E6),
        fg: const Color(0xFFE67700),
      ),
      ContactStatus.blocked: (
        label: 'BLOCKED',
        bg: const Color(0xFFFFF0F0),
        fg: const Color(0xFFC92A2A),
      ),
    };
    final s = map[status]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        s.label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: s.fg,
          letterSpacing: 0.5,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final ContactCategory category;

  const _CategoryBadge({required this.category});

  String get _label {
    switch (category) {
      case ContactCategory.family:
        return 'FAMILY';
      case ContactCategory.friends:
        return 'FRIENDS';
      case ContactCategory.education:
        return 'EDUCATION';
      case ContactCategory.unknown:
        return 'UNKNOWN';
      case ContactCategory.all:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Color(0xFF868E96),
          letterSpacing: 0.5,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW  –  CONTACT DETAIL BOTTOM SHEET
// ══════════════════════════════════════════════════════════════

class ContactDetailSheet extends StatelessWidget {
  final ContactModel contact;

  const ContactDetailSheet({super.key, required this.contact});

  static const _navy = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),

          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE9ECEF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 28),

          // Avatar + name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _ContactAvatar(contact: contact, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _navy,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        contact.phone,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF868E96),
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 7),
                      _StatusBadge(status: contact.status),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _SheetStatCard(label: 'Total Calls', value: '${contact.calls}'),
                const SizedBox(width: 10),
                _SheetStatCard(
                  label: 'Category',
                  value: _catLabel(contact.category),
                ),
                const SizedBox(width: 10),
                _SheetStatCard(label: 'Last Seen', value: contact.lastSeen),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tags
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TAGS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFADB5BD),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: contact.tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: contact.color.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: contact.color.withValues(alpha: .25),
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: contact.color,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text(
                      'Call Log',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: contact.status == ContactStatus.blocked
                          ? const Color(0xFF2F9E44)
                          : const Color(0xFFC92A2A),
                      side: BorderSide(
                        color: contact.status == ContactStatus.blocked
                            ? const Color(0xFF2F9E44)
                            : const Color(0xFFC92A2A),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      contact.status == ContactStatus.blocked
                          ? Icons.lock_open_outlined
                          : Icons.block,
                      size: 18,
                    ),
                    label: Text(
                      contact.status == ContactStatus.blocked
                          ? 'Unblock'
                          : 'Block',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _catLabel(ContactCategory c) {
    switch (c) {
      case ContactCategory.family:
        return 'Family';
      case ContactCategory.friends:
        return 'Friends';
      case ContactCategory.education:
        return 'Education';
      case ContactCategory.unknown:
        return 'Unknown';
      case ContactCategory.all:
        return '—';
    }
  }
}

class _SheetStatCard extends StatelessWidget {
  final String label;
  final String value;

  const _SheetStatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFFADB5BD),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW  –  EMPTY STATE
// ══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No contacts found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF868E96),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different search or filter',
            style: TextStyle(fontSize: 13, color: Color(0xFFADB5BD)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEW  –  BOTTOM NAV
// ══════════════════════════════════════════════════════════════
