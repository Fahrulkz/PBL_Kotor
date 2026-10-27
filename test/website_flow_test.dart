import 'package:aplikasi_guru/core/network/api_exception.dart';
import 'package:aplikasi_guru/core/url_opener.dart';
import 'package:aplikasi_guru/features/website/data/website_models.dart';
import 'package:aplikasi_guru/features/website/providers/website_providers.dart';
import 'package:aplikasi_guru/features/website/screens/website_main_layout.dart';
import 'package:aplikasi_guru/main_website.dart';
import 'package:aplikasi_guru/repositories/website_repository.dart';
import 'package:aplikasi_guru/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_env.dart';
import 'support/web_fakes.dart';

Future<ProviderContainer> _boot(
  WidgetTester t,
  FakeWebsiteRepository repo, {
  Size size = const Size(390, 844),
}) async {
  await prepareFonts();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [websiteRepositoryProvider.overrideWithValue(repo)],
    child: const WebsiteApp(),
  ));
  await t.pumpAndSettle();
  return ProviderScope.containerOf(t.element(find.byType(WebsiteMainLayout)));
}

Future<void> _tapVisible(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _drainToast(WidgetTester t) => t.pump(const Duration(seconds: 3));

void main() {
  final errors = captureErrors();

  testWidgets('home hero, PPDB banner and contact text all come from admin-managed pages', (t) async {
    await _boot(t, FakeWebsiteRepository());

    expect(find.text('Sekolah Kami\nUntuk Anak Bangsa'), findsOneWidget);
    expect(find.text('Subjudul dari admin.'), findsOneWidget);
    expect(find.text('Kota Blitar'), findsWidgets);
    expect(find.text('Banner PPDB dari admin.'), findsOneWidget);
    expect(find.text('Ajakan kontak dari admin.'), findsOneWidget);
    expect(find.textContaining('Informasi sekolah dalam satu tempat'), findsNothing);
    expect(find.textContaining('diumumkan oleh pihak sekolah'), findsNothing);
    expect(errors, isEmpty);
  });

  testWidgets('empty hero falls back to the school name and decorative texts disappear', (t) async {
    final repo = FakeWebsiteRepository()
      ..pages.removeWhere((k, _) => const {
            'hero-kicker', 'hero-title', 'hero-subtitle', 'ppdb-banner', 'kontak-ajakan',
          }.contains(k));
    await _boot(t, repo);

    expect(find.text(repo.info.nama), findsWidgets);
    expect(find.text('Subjudul dari admin.'), findsNothing);
    expect(find.text('Informasi belum tersedia.'), findsNothing);
    expect(errors, isEmpty);
  });

  testWidgets('mobile home: content from the repository, no demo text, WhatsApp number', (t) async {
    final container = await _boot(t, FakeWebsiteRepository());
    expect(find.text('Informasi Terbaru'), findsOneWidget);
    expect(find.text('Jadwal Libur Semester Ganjil'), findsOneWidget);
    expect(find.text('Bazar Kreativitas Siswa'), findsNothing);
    expect(find.text('Selamat datang di SDN 02 Pakunden.'), findsOneWidget);
    expect(find.textContaining('contoh'), findsNothing);
    expect(find.textContaining('Contoh'), findsNothing);
    expect(find.textContaining('diisi oleh pihak sekolah'), findsNothing);

    await t.tap(find.byType(FloatingActionButton));
    await t.pump();
    expect(find.text('Membuka WhatsApp…'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 900));
    expect(find.textContaining('saya ingin bertanya tentang sekolah'), findsOneWidget);
    expect(find.text('Nomor admin: 6281234567890'), findsOneWidget);
    await t.tap(find.text('Batal'));
    await t.pumpAndSettle();

    await t.tap(find.text('☰ Menu'));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(Drawer), matching: find.text('FAQ')));
    await t.pumpAndSettle();
    expect(container.read(activeNavProvider), WebsiteNav.faq);
    expect(errors, isEmpty);
  });

  testWidgets('WhatsApp: "Lanjutkan" opens the wa.me link, and failure is reported', (t) async {
    final opened = <Uri>[];
    var succeed = true;
    await prepareFonts();
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [
        websiteRepositoryProvider.overrideWithValue(FakeWebsiteRepository()),
        urlOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return succeed;
        }),
      ],
      child: const WebsiteApp(),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byType(FloatingActionButton));
    await t.pump();
    await t.pump(const Duration(milliseconds: 900));
    await t.tap(find.text('Batal'));
    await t.pumpAndSettle();
    expect(opened, isEmpty);

    await t.tap(find.byType(FloatingActionButton));
    await t.pump();
    await t.pump(const Duration(milliseconds: 900));
    await t.tap(find.text('Lanjutkan'));
    await t.pumpAndSettle();
    expect(opened, hasLength(1));
    expect(opened.single.host, 'wa.me');
    expect(opened.single.path, '/6281234567890');
    expect(
      opened.single.queryParameters['text'],
      'Halo Admin, saya ingin bertanya tentang sekolah.',
    );
    expect(find.textContaining('Tidak dapat membuka WhatsApp'), findsNothing);

    succeed = false;
    await t.pump(const Duration(seconds: 3));
    await t.tap(find.byType(FloatingActionButton));
    await t.pump();
    await t.pump(const Duration(milliseconds: 900));
    await t.tap(find.text('Lanjutkan'));
    await t.pumpAndSettle();
    expect(find.textContaining('Tidak dapat membuka WhatsApp'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(errors, isEmpty);
  });

  testWidgets('footer shows the school contact details and no demo note', (t) async {
    await _boot(t, FakeWebsiteRepository());
    await t.scrollUntilVisible(
      find.textContaining('Jl. Merdeka No. 1'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Telepon: 0342-123456'), findsOneWidget);
    expect(find.textContaining('Data contoh'), findsNothing);
    expect(find.textContaining('© 2026'), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('missing page text falls back to a neutral message', (t) async {
    final container = await _boot(t, FakeWebsiteRepository());
    container.read(activeNavProvider.notifier).openProfil(ProfilSection.sejarah);
    await t.pumpAndSettle();
    expect(find.text('Informasi belum tersedia.'), findsOneWidget);
    expect(find.textContaining('['), findsNothing);
    expect(errors, isEmpty);
  });

  testWidgets('faq: search, category and ExpansionTile', (t) async {
    final container = await _boot(t, FakeWebsiteRepository());
    container.read(activeNavProvider.notifier).open(WebsiteNav.faq);
    await t.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(6));

    await t.enterText(find.byType(TextField), 'zzz');
    await t.pumpAndSettle();
    expect(find.text('Pertanyaan tidak ditemukan.'), findsOneWidget);
    await t.enterText(find.byType(TextField), '');
    await t.pumpAndSettle();

    await t.tap(find.text('Umum').first);
    await t.pumpAndSettle();
    expect(container.read(faqCategoryProvider), FaqKategori.umum);
    expect(find.byType(ExpansionTile), findsNWidgets(2));

    await t.tap(find.text('Bagaimana menghubungi sekolah?'));
    await t.pumpAndSettle();
    expect(find.text('Lewat WhatsApp.'), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('information: filter, sort, detail from the server, back', (t) async {
    final container = await _boot(t, FakeWebsiteRepository());
    container.read(activeNavProvider.notifier).open(WebsiteNav.informasi);
    await t.pumpAndSettle();
    expect(find.text('Jadwal Libur Semester Ganjil'), findsOneWidget);

    await t.tap(find.text('PPDB').first);
    await t.pumpAndSettle();
    expect(container.read(filteredNewsProvider).length, 1);
    expect(find.text('Pembukaan PPDB Tahun Ajaran 2027/2028'), findsOneWidget);
    expect(find.text('Bazar Kreativitas Siswa'), findsNothing);

    await t.enterText(find.byType(TextField), 'zzz');
    await t.pumpAndSettle();
    expect(find.text('Informasi tidak ditemukan.'), findsOneWidget);
    await t.tap(find.text('Reset Filter'));
    await t.pumpAndSettle();
    expect(container.read(newsCategoryProvider), isNull);
    expect(container.read(newsSearchQueryProvider), '');

    container.read(newsOrderProvider.notifier).set(NewsOrder.terlama);
    await t.pumpAndSettle();
    expect(container.read(filteredNewsProvider).first.slug, 'bazar');

    await _tapVisible(t, find.text('Bazar Kreativitas Siswa').first);
    expect(container.read(newsDetailSlugProvider), 'bazar');
    expect(find.text('Isi lengkap: Bazar Kreativitas Siswa.'), findsOneWidget);
    expect(find.text('Informasi Terkait'), findsOneWidget);

    await _tapVisible(t, find.text('Kembali ke Informasi'));
    expect(container.read(newsDetailSlugProvider), isNull);
    await _drainToast(t);
    expect(errors, isEmpty);
  });

  testWidgets('information: load failure shows a retry that recovers', (t) async {
    final repo = FakeWebsiteRepository()
      ..failNews = const ApiException(type: ApiErrorType.server, message: 'Server sibuk.');
    final container = await _boot(t, repo);
    container.read(activeNavProvider.notifier).open(WebsiteNav.informasi);
    await t.pumpAndSettle();
    expect(find.text('Data belum dapat dimuat.'), findsOneWidget);
    expect(find.text('Server sibuk.'), findsOneWidget);

    repo.failNews = null;
    await t.tap(find.widgetWithText(CustomButton, 'Coba Lagi'));
    await t.pumpAndSettle();
    expect(find.text('Jadwal Libur Semester Ganjil'), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('activities: filter, detail and photo viewer from server urls', (t) async {
    final container = await _boot(t, FakeWebsiteRepository());
    container.read(activeNavProvider.notifier).open(WebsiteNav.kegiatan);
    await t.pumpAndSettle();

    await t.tap(find.text('Upacara').first);
    await t.pumpAndSettle();
    expect(container.read(filteredActivitiesProvider).length, 1);

    await _tapVisible(t, find.text('Kegiatan Upacara').first);
    expect(container.read(activityDetailSlugProvider), 'kegiatan-3');
    expect(find.text('Deskripsi kegiatan 3.'), findsOneWidget);

    await _tapVisible(t, find.text('Foto 1').first);
    expect(find.text('→'), findsOneWidget);
    await t.tap(find.text('→'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tutup'));
    await t.pumpAndSettle();
    expect(errors, isEmpty);
  });

  testWidgets('profile, identity, staff, PPDB, contact, facilities and academics', (t) async {
    final container = await _boot(t, FakeWebsiteRepository());
    final nav = container.read(activeNavProvider.notifier);

    nav.open(WebsiteNav.profil);
    await t.pumpAndSettle();
    expect(find.text('Sekolah dasar negeri di Kota Blitar.'), findsOneWidget);
    await _tapVisible(t, find.text('Sejarah →'));
    expect(container.read(selectedProfilSectionProvider), ProfilSection.sejarah);

    nav.openProfil(ProfilSection.identitas);
    await t.pumpAndSettle();
    expect(find.text('20500001'), findsOneWidget);
    expect(find.text('Jl. Merdeka No. 1, Blitar'), findsWidgets);

    nav.openProfil(ProfilSection.guru);
    await t.pumpAndSettle();
    expect(find.text('Bu Rina'), findsOneWidget);
    expect(find.text('Wali Kelas 5A'), findsOneWidget);

    nav.open(WebsiteNav.ppdb);
    await t.pumpAndSettle();
    expect(find.text('PPDB dibuka setiap Januari.'), findsOneWidget);
    expect(find.text('Unduh dokumen'), findsNothing);
    expect(find.text('Kapan pendaftaran dimulai?'), findsOneWidget);
    expect(find.text('Apakah ada SPP?'), findsNothing);

    nav.open(WebsiteNav.kontak);
    await t.pumpAndSettle();
    expect(find.text('0342-123456'), findsOneWidget);
    expect(find.text('Butuh bantuan?'), findsOneWidget);

    nav.open(WebsiteNav.fasilitas);
    await t.pumpAndSettle();
    await t.tap(find.text('Laboratorium Komputer'));
    await t.pumpAndSettle();
    expect(find.text('Berisi 20 unit komputer.'), findsWidgets);
    await t.tap(find.widgetWithText(CustomButton, 'Tutup'));
    await t.pumpAndSettle();

    nav.open(WebsiteNav.akademik);
    await t.pumpAndSettle();
    expect(find.text('Kalender Akademik'), findsOneWidget);
    expect(find.text('28'), findsNothing);
    expect(errors, isEmpty);
  });

  testWidgets('desktop: AppBar nav buttons, no FAB, no hamburger', (t) async {
    final container = await _boot(t, FakeWebsiteRepository(), size: const Size(1500, 900));
    expect(find.text('☰ Menu'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);

    await t.tap(find.descendant(of: find.byType(AppBar), matching: find.text('Kontak')));
    await t.pumpAndSettle();
    expect(container.read(activeNavProvider), WebsiteNav.kontak);

    await t.tap(find.descendant(of: find.byType(AppBar), matching: find.text('Beranda')));
    await t.pumpAndSettle();
    expect(find.text('Sambutan Sekolah'), findsOneWidget);
    expect(errors, isEmpty);
  });
}
