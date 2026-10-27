import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../../../widgets/app_overlays.dart';
import '../../../widgets/async_body.dart';
import '../../../widgets/avatar.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/status_badge.dart';
import '../data/admin_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_dialogs.dart';
import 'account_management_screen.dart';
import 'activity_log_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_settings_screen.dart';
import 'class_management_screen.dart';
import 'cms_faq_contact_screen.dart';
import 'cms_facilities_activities_screen.dart';
import 'cms_home_text_screen.dart';
import 'cms_posts_screen.dart';

const _desktopBreakpoint = 900.0;

class AdminMainLayout extends ConsumerWidget {
  const AdminMainLayout({super.key, this.onLogout});

  final VoidCallback? onLogout;

  void _confirmLogout(BuildContext context) {
    showAdminConfirm(
      adminDialogContext(context),
      title: 'Apakah Anda yakin ingin keluar?',
      description: 'Anda perlu masuk kembali untuk membuka panel admin.',
      confirmLabel: 'Keluar',
      onConfirm: () {
        AppToast.show('Anda telah keluar');
        onLogout?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(activeMenuProvider);

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > _desktopBreakpoint;

        Widget sidebar({required bool inDrawer}) => AdminSidebar(
          active: menu,
          onSelect: (m) {
            if (inDrawer) Navigator.of(context).pop();
            ref.read(activeMenuProvider.notifier).select(m);
          },
          onLogout: () {
            if (inDrawer) Navigator.of(context).pop();
            _confirmLogout(context);
          },
        );

        return Scaffold(
          drawer: wide ? null : Drawer(width: 270, child: SafeArea(child: sidebar(inDrawer: true))),
          body: wide
              ? Row(
                  children: [
                    SizedBox(width: 240, child: sidebar(inDrawer: false)),
                    const Expanded(child: _AdminContent(wide: true)),
                  ],
                )
              : const SafeArea(
                  child: Column(
                    children: [
                      _NarrowBar(),
                      Expanded(child: _AdminContent(wide: false)),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.active,
    required this.onSelect,
    required this.onLogout,
  });

  final AdminMenu active;
  final ValueChanged<AdminMenu> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.su,
        border: Border(right: BorderSide(color: c.mi)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(8, 0, 8, 16), child: _Logo()),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final m in AdminMenu.values.where((m) => !m.website))
                      _SidebarItem(label: m.label, selected: m == active, onTap: () => onSelect(m)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                      child: Text('Kelola Website', style: context.styleKick),
                    ),
                    for (final m in AdminMenu.values.where((m) => m.website))
                      _SidebarItem(label: m.label, selected: m == active, onTap: () => onSelect(m)),
                  ],
                ),
              ),
            ),
            _SidebarItem(label: 'Keluar', selected: false, onTap: onLogout),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            gradient: const LinearGradient(
              begin: Alignment(-0.34, -0.94),
              end: Alignment(0.34, 0.94),
              colors: [AppColors.darkCardStart, AppColors.darkCardEnd],
            ),
          ),
          child: Text(
            '02',
            style: context.styleBadge.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.onDarkCard,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Panel Admin', style: context.styleBold),
              Text('SDN 02 Pakunden', style: context.styleCaption),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? c.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 42),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: context.styleMedium.copyWith(color: selected ? c.su : c.sl),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NarrowBar extends ConsumerWidget {
  const _NarrowBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final menu = ref.watch(activeMenuProvider);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.su,
        border: Border(bottom: BorderSide(color: c.mi)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Buka menu',
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            Expanded(child: Text(menu.label, style: context.styleBold)),
          ],
        ),
      ),
    );
  }
}

class _AdminContent extends ConsumerWidget {
  const _AdminContent({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(activeMenuProvider);
    final classCode = ref.watch(selectedClassCodeProvider);

    // Layar Kelola Website memuat datanya sendiri; tidak ikut gagal bila dataset akun gagal dimuat.
    final website = switch (menu) {
      AdminMenu.webTeks => const CmsHomeTextScreen(),
      AdminMenu.webBerita => const CmsPostsScreen(),
      AdminMenu.webFasilitas => const CmsFacilitiesActivitiesScreen(),
      AdminMenu.webFaq => const CmsFaqContactScreen(),
      _ => null,
    };

    final body = switch (menu) {
      AdminMenu.dashboard => const AdminDashboardScreen(),
      AdminMenu.kelas => const ClassManagementScreen(),
      AdminMenu.akun => const AccountManagementScreen(),
      AdminMenu.log => const ActivityLogScreen(),
      AdminMenu.pengaturan => const AdminSettingsScreen(),
      _ => const SizedBox.shrink(),
    };

    return SingleChildScrollView(
      key: ValueKey('$menu-$classCode'),
      padding: wide
          ? const EdgeInsets.fromLTRB(32, 24, 32, 48)
          : const EdgeInsets.fromLTRB(14, 16, 14, 40),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wide) const _TopBar(),
              website ??
                  AsyncBody<AdminDataset>(
                    value: ref.watch(adminDataProvider),
                    onRetry: () => ref.invalidate(adminDataProvider),
                    loading: Column(children: [for (var i = 0; i < 3; i++) const SkeletonBlock()]),
                    builder: (_) => body,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentAdminProvider)?.name ?? 'Admin';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: Text(
              formatFullDate(ref.watch(todayProvider)),
              style: context.styleCaption.copyWith(fontSize: 13),
            ),
          ),
          StatusBadge(label: name),
          const SizedBox(width: 12),
          Avatar(name: name),
        ],
      ),
    );
  }
}
