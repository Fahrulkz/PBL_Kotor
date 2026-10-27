import 'dart:typed_data';

import 'package:aplikasi_guru/core/media_picker.dart';
import 'package:aplikasi_guru/core/network/api_exception.dart';
import 'package:aplikasi_guru/features/admin/data/cms_models.dart';
import 'package:aplikasi_guru/features/admin/screens/admin_main_layout.dart';
import 'package:aplikasi_guru/features/admin/widgets/admin_common.dart';
import 'package:aplikasi_guru/repositories/admin_repository.dart';
import 'package:aplikasi_guru/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';
import 'support/test_env.dart';

class _FakePicker implements MediaPicker {
  final queue = <PickedImage?>[];
  var calls = 0;

  void add([String name = 'foto.png']) =>
      queue.add(PickedImage(name: name, bytes: Uint8List.fromList([1, 2, 3])));

  @override
  Future<PickedImage?> pick() async {
    calls++;
    return queue.isEmpty ? null : queue.removeAt(0);
  }
}

Future<void> _boot(WidgetTester t, FakeAdminRepository repo, {MediaPicker? picker}) async {
  await prepareFonts();
  t.view.physicalSize = const Size(1400, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        adminRepositoryProvider.overrideWithValue(repo),
        if (picker != null) mediaPickerProvider.overrideWithValue(picker),
      ],
      child: harnessApp(const AdminMainLayout()),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester t, String label) async {
  await t.tap(find.descendant(of: find.byType(AdminSidebar), matching: find.text(label)));
  await t.pumpAndSettle();
}

Future<void> _drainToast(WidgetTester t) => t.pump(const Duration(seconds: 3));

Finder _dialogFields() => find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));

Finder _inDialog(String text) => find.descendant(of: find.byType(Dialog), matching: find.text(text));

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

ApiException _invalid(Map<String, String> fields, [String message = 'Data yang dikirim tidak valid.']) =>
    ApiException(
      type: ApiErrorType.validation,
      message: message,
      statusCode: 422,
      fieldErrors: fields,
    );

bool _disabled(WidgetTester t, Finder f) => t.widget<CustomButton>(f).onPressed == null;

void main() {
  final errors = captureErrors();

  group('menu', () {
    testWidgets('sidebar has a Kelola Website group that opens the four CMS screens', (t) async {
      await _boot(t, FakeAdminRepository());

      expect(
        find.descendant(of: find.byType(AdminSidebar), matching: find.text('Kelola Website')),
        findsOneWidget,
      );
      for (final title in [
        'Pengaturan Beranda & Teks',
        'Kelola Berita & Pengumuman',
        'Kelola Fasilitas & Kegiatan',
        'Kelola FAQ & Kontak',
      ]) {
        await _openMenu(t, title);
        expect(
          find.descendant(of: find.byType(PageHeader), matching: find.text(title)),
          findsOneWidget,
          reason: title,
        );
      }
      expect(errors, isEmpty);
    });

    testWidgets('website screens still load when the account dataset fails', (t) async {
      final repo = FakeAdminRepository()
        ..failFetch = apiError('Server tidak merespons.', type: ApiErrorType.server);
      await _boot(t, repo);
      expect(find.text('Data belum dapat dimuat.'), findsOneWidget);

      await _openMenu(t, 'Kelola Berita & Pengumuman');

      expect(find.text('Libur Semester'), findsOneWidget);
      expect(find.text('Data belum dapat dimuat.'), findsNothing);
      expect(errors, isEmpty);
    });

    testWidgets('narrow layout reaches the group through the drawer', (t) async {
      await prepareFonts();
      t.view.physicalSize = const Size(600, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: [adminRepositoryProvider.overrideWithValue(FakeAdminRepository())],
          child: harnessApp(const AdminMainLayout()),
        ),
      );
      await t.pumpAndSettle();

      await t.tap(find.byTooltip('Buka menu'));
      await t.pumpAndSettle();
      expect(find.text('Kelola Website'), findsOneWidget);
      await t.tap(find.text('Kelola FAQ & Kontak'));
      await t.pumpAndSettle();

      expect(find.text('Pertanyaan Umum (FAQ)'), findsOneWidget);
      expect(errors, isEmpty);
    });
  });

  group('beranda & teks', () {
    testWidgets('save is disabled until something changes and sends only the changed texts', (t) async {
      final repo = FakeAdminRepository();
      await _boot(t, repo);
      await _openMenu(t, 'Pengaturan Beranda & Teks');

      final save = find.widgetWithText(CustomButton, 'Simpan Perubahan');
      expect(save, findsNWidgets(2));
      expect(_disabled(t, save.first), isTrue);
      expect(find.text('Judul awal'), findsOneWidget);

      await t.enterText(find.byType(TextField).at(0), '  Judul Baru  ');
      await t.pump();
      expect(_disabled(t, save.first), isFalse);
      await t.tap(save.first);
      await t.pumpAndSettle();

      expect(repo.savedPageBatches, [
        {'hero-title': 'Judul Baru'},
      ]);
      expect(find.text('Teks website berhasil disimpan.'), findsOneWidget);
      expect(_disabled(t, save.first), isTrue);
      await _drainToast(t);
      expect(errors, isEmpty);
    });

    testWidgets('other groups are collapsible and editable', (t) async {
      final repo = FakeAdminRepository();
      await _boot(t, repo);
      await _openMenu(t, 'Pengaturan Beranda & Teks');

      expect(find.text('Visi awal'), findsNothing);
      await _tap(t, find.text('1 teks'));
      expect(find.text('Visi awal'), findsOneWidget);
      await t.enterText(find.byType(TextField).last, 'Visi baru');
      await t.pump();
      await t.tap(find.widgetWithText(CustomButton, 'Simpan Perubahan').first);
      await t.pumpAndSettle();

      expect(repo.savedPageBatches.single, {'visi': 'Visi baru'});
      await _drainToast(t);
    });

    testWidgets('a server rejection is shown under the field and keeps the edit', (t) async {
      final repo = FakeAdminRepository()..cmsError = _invalid({'hero-title': 'Teks terlalu panjang.'});
      await _boot(t, repo);
      await _openMenu(t, 'Pengaturan Beranda & Teks');

      await t.enterText(find.byType(TextField).at(0), 'Judul baru');
      await t.pump();
      await t.tap(find.widgetWithText(CustomButton, 'Simpan Perubahan').first);
      await t.pumpAndSettle();

      expect(find.text('Teks terlalu panjang.'), findsOneWidget);
      expect(find.text('Judul baru'), findsOneWidget);
      expect(_disabled(t, find.widgetWithText(CustomButton, 'Simpan Perubahan').first), isFalse);
      await _drainToast(t);
      expect(errors, isEmpty);
    });
  });

  group('berita & pengumuman', () {
    testWidgets('lists posts with status badges and filters by status', (t) async {
      await _boot(t, FakeAdminRepository());
      await _openMenu(t, 'Kelola Berita & Pengumuman');

      expect(find.text('Libur Semester'), findsOneWidget);
      expect(find.text('Lomba Puisi'), findsOneWidget);

      final chips = find.byType(AdminChipBar<ContentStatus?>);
      await t.tap(find.descendant(of: chips, matching: find.text('Draf')));
      await t.pumpAndSettle();

      expect(find.text('Libur Semester'), findsNothing);
      expect(find.text('Lomba Puisi'), findsOneWidget);
      expect(errors, isEmpty);
    });

    testWidgets('adding requires a title and then creates the post', (t) async {
      final repo = FakeAdminRepository();
      await _boot(t, repo);
      await _openMenu(t, 'Kelola Berita & Pengumuman');

      await _tap(t, find.text('+ Tambah'));
      await _tap(t, _inDialog('Tambah'));
      expect(find.text('Kolom ini wajib diisi.'), findsOneWidget);
      expect(repo.cmsCalls, isEmpty);

      await t.enterText(_dialogFields().at(0), '  Berita Baru  ');
      await t.enterText(_dialogFields().at(2), 'Isi berita baru.');
      await _tap(t, _inDialog('Tambah'));

      expect(find.byType(Dialog), findsNothing);
      final input = repo.postInputs.single;
      expect((input.judul, input.isi, input.kategori), ('Berita Baru', 'Isi berita baru.', 'Berita'));
      expect((input.status, input.gambarUrl, input.tanggal), (ContentStatus.draft, null, null));
      expect(find.text('Berita Baru'), findsOneWidget);
      await _drainToast(t);
      expect(errors, isEmpty);
    });

    testWidgets('server field errors keep the dialog open next to the field', (t) async {
      final repo = FakeAdminRepository()
        ..cmsError = _invalid({
          'gambar_url': 'Gunakan gambar yang diunggah atau tautan yang diawali http:// atau https://.',
        });
      await _boot(t, repo);
      await _openMenu(t, 'Kelola Berita & Pengumuman');
      await _tap(t, find.text('+ Tambah'));
      await t.enterText(_dialogFields().at(0), 'Judul');

      await _tap(t, _inDialog('Tambah'));

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.textContaining('Gunakan gambar yang diunggah'), findsOneWidget);

      await _tap(t, _inDialog('Tambah'));
      expect(find.byType(Dialog), findsNothing);
      expect(repo.cmsPosts.first.judul, 'Judul');
      await _drainToast(t);
    });

    testWidgets('an error without a field (e.g. duplicate title) is shown in the dialog', (t) async {
      final repo = FakeAdminRepository()
        ..cmsError = const ApiException(
          type: ApiErrorType.conflict,
          message: 'Judul ini sudah dipakai. Coba judul lain.',
          statusCode: 409,
        );
      await _boot(t, repo);
      await _openMenu(t, 'Kelola Berita & Pengumuman');
      await _tap(t, find.text('+ Tambah'));
      await t.enterText(_dialogFields().at(0), 'Judul');

      await _tap(t, _inDialog('Tambah'));

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Judul ini sudah dipakai. Coba judul lain.'), findsOneWidget);
    });

    testWidgets('editing loads the full post and saves by slug', (t) async {
      final repo = FakeAdminRepository();
      await _boot(t, repo);
      await _openMenu(t, 'Kelola Berita & Pengumuman');

      await _tap(t, find.text('Edit').first);
      expect(find.text('Isi pengumuman libur.'), findsOneWidget);
      expect(find.text('Edit Berita / Pengumuman'), findsOneWidget);

      await t.enterText(_dialogFields().at(0), 'Libur Panjang');
      await _tap(t, _inDialog('Simpan'));

      expect(repo.cmsCalls, ['updatePost:libur-semester']);
      expect(find.text('Libur Panjang'), findsOneWidget);
      expect(find.text('Libur Semester'), findsNothing);
      await _drainToast(t);
      expect(errors, isEmpty);
    });

    testWidgets('delete asks for confirmation and then removes the post', (t) async {
      final repo = FakeAdminRepository();
      await _boot(t, repo);
      await _openMenu(t, 'Kelola Berita & Pengumuman');

      await _tap(t, find.text('Hapus').first);
      expect(find.text('Hapus "Libur Semester"?'), findsOneWidget);
      await _tap(t, _inDialog('Batal'));
      expect(repo.cmsCalls, isEmpty);

      await _tap(t, find.text('Hapus').first);
      await _tap(t, _inDialog('Hapus'));

      expect(repo.cmsCalls, ['deletePost:libur-semester']);
      expect(find.text('Libur Semester'), findsNothing);
      await _drainToast(t);
      expect(errors, isEmpty);
    });

    testWidgets('picking an image uploads it and the post keeps the returned address', (t) async {
      final repo = FakeAdminRepository();
      final picker = _FakePicker()..add('foto.png');
      await _boot(t, repo, picker: picker);
      await _openMenu(t, 'Kelola Berita & Pengumuman');
      await _tap(t, find.text('+ Tambah'));
      await t.enterText(_dialogFields().at(0), 'Dengan Gambar');

      await _tap(t, _inDialog('Pilih Gambar'));

      expect(repo.uploads.single.$1, 'foto.png');
      expect(repo.uploads.single.$2, [1, 2, 3]);
      expect(_inDialog('Ganti Gambar'), findsOneWidget);
      expect(_inDialog('Hapus Gambar'), findsOneWidget);

      await _tap(t, _inDialog('Tambah'));

      expect(repo.postInputs.single.gambarUrl, '/media/upload-1.jpg');
      await _drainToast(t);
      expect(errors, isEmpty);
    });

    testWidgets('removing the picked image sends no image, cancelling the picker changes nothing', (t) async {
      final repo = FakeAdminRepository();
      final picker = _FakePicker()
        ..queue.add(null)
        ..add();
      await _boot(t, repo, picker: picker);
      await _openMenu(t, 'Kelola Berita & Pengumuman');
      await _tap(t, find.text('+ Tambah'));
      await t.enterText(_dialogFields().at(0), 'Tanpa Gambar');

      await _tap(t, _inDialog('Pilih Gambar'));
      expect(repo.uploads, isEmpty);
      expect(_inDialog('Pilih Gambar'), findsOneWidget);

      await _tap(t, _inDialog('Pilih Gambar'));
      await _tap(t, _inDialog('Hapus Gambar'));
      expect(_inDialog('Pilih Gambar'), findsOneWidget);
      await _tap(t, _inDialog('Tambah'));

      expect(repo.postInputs.single.gambarUrl, isNull);
      await _drainToast(t);
    });

    testWidgets('a rejected upload shows the server message and blocks nothing', (t) async {
      final repo = FakeAdminRepository()
        ..cmsError = _invalid({'file': 'Berkas harus berupa gambar JPEG, PNG, atau WebP yang valid.'});
      final picker = _FakePicker()..add('x.gif');
      await _boot(t, repo, picker: picker);
      await _openMenu(t, 'Kelola Berita & Pengumuman');
      await _tap(t, find.text('+ Tambah'));

      await _tap(t, _inDialog('Pilih Gambar'));

      expect(find.textContaining('Berkas harus berupa gambar'), findsOneWidget);
      expect(repo.uploads, isEmpty);
      expect(_inDialog('Pilih Gambar'), findsOneWidget);
      expect(errors, isEmpty);
    });
  });

  group('fasilitas & kegiatan', () {
    testWidgets('facilities: add, edit and delete', (t) async {
      final repo = FakeAdminRepository();
      await _boot(t, repo);
      await _openMenu(t, 'Kelola Fasilitas & Kegiatan');
      expect(find.text('Perpustakaan'), findsOneWidget);

      await _tap(t, find.text('+ Tambah Fasilitas'));
      await _tap(t, _inDialog('Tambah'));
      expect(find.text('Kolom ini wajib diisi.'), findsOneWidget);
      await t.enterText(_dialogFields().at(0), 'Lapangan');
      await t.enterText(_dialogFields().at(1), 'Untuk upacara.');
      await t.enterText(_dialogFields().at(2), '5');
      await _tap(t, find.descendant(of: find.byType(Dialog), matching: find.byType(Switch)));
      await _tap(t, _inDialog('Tambah'));

      final created = repo.cmsFacilities.last;
      expect((created.nama, created.deskripsi, created.urutan, created.tampil), ('Lapangan', 'Untuk upacara.', 5, false));
      expect(find.text('Lapangan'), findsOneWidget);
      await _drainToast(t);

      await _tap(t, find.text('Edit').last);
      await t.enterText(_dialogFields().at(0), 'Lapangan Olahraga');
      await _tap(t, _inDialog('Simpan'));
      expect(find.text('Lapangan Olahraga'), findsOneWidget);
      await _drainToast(t);

      await _tap(t, find.text('Hapus').first);
      await _tap(t, _inDialog('Hapus'));
      expect(find.text('Perpustakaan'), findsNothing);
      expect(repo.cmsCalls.last, startsWith('deleteFacility'));
      await _drainToast(t);
      expect(errors, isEmpty);
    });

    testWidgets('activities: multiple photos can be added and removed one by one', (t) async {
      final repo = FakeAdminRepository();
      final picker = _FakePicker()
        ..add('a.png')
        ..add('b.png');
      await _boot(t, repo, picker: picker);
      await _openMenu(t, 'Kelola Fasilitas & Kegiatan');
      await _tap(t, find.text('Kegiatan & Galeri'));
      expect(find.text('Latihan Pramuka'), findsOneWidget);

      await _tap(t, find.text('+ Tambah Kegiatan'));
      await t.enterText(_dialogFields().at(0), 'Lomba Baru');
      await _tap(t, _inDialog('Tambah Foto'));
      await _tap(t, _inDialog('Tambah Foto'));
      expect(find.text('Foto galeri (2/20)'), findsOneWidget);

      await _tap(t, find.byTooltip('Hapus foto 1'));
      expect(find.text('Foto galeri (1/20)'), findsOneWidget);
      await _tap(t, _inDialog('Tambah'));

      final created = repo.cmsActivities.first;
      expect(created.judul, 'Lomba Baru');
      expect(created.fotoUrls, ['/media/upload-2.jpg']);
      expect(created.status, ContentStatus.draft);
      await _drainToast(t);
      expect(errors, isEmpty);
    });

    testWidgets('activities: edit keeps existing photos and delete confirms', (t) async {
      final repo = FakeAdminRepository();
      await _boot(t, repo);
      await _openMenu(t, 'Kelola Fasilitas & Kegiatan');
      await _tap(t, find.text('Kegiatan & Galeri'));

      await _tap(t, find.text('Edit').first);
      expect(find.text('Foto galeri (1/20)'), findsOneWidget);
      await _tap(t, _inDialog('Simpan'));
      expect(repo.cmsActivities.single.fotoUrls, ['/media/a.jpg']);
      await _drainToast(t);

      await _tap(t, find.text('Hapus').first);
      await _tap(t, _inDialog('Hapus'));
      expect(repo.cmsActivities, isEmpty);
      expect(find.text('Belum ada kegiatan.'), findsOneWidget);
      await _drainToast(t);
      expect(errors, isEmpty);
    });
  });

  group('faq & kontak', () {
    testWidgets('the contact form normalises the WhatsApp number from the server reply', (t) async {
      final repo = FakeAdminRepository();
      await _boot(t, repo);
      await _openMenu(t, 'Kelola FAQ & Kontak');

      expect(find.text('6281200000000'), findsOneWidget);
      final save = find.widgetWithText(CustomButton, 'Simpan Kontak');
      expect(_disabled(t, save), isTrue);

      await t.enterText(find.byType(TextField).at(8), '0812 3456 7890');
      await t.enterText(find.byType(TextField).at(4), 'Jl. Mawar 1');
      await t.pump();
      expect(_disabled(t, save), isFalse);
      await _tap(t, save);

      expect(repo.cmsSchool.whatsapp, '6281234567890');
      expect(repo.cmsSchool.alamat, 'Jl. Mawar 1');
      expect(find.text('6281234567890'), findsOneWidget);
      expect(_disabled(t, save), isTrue);
      await _drainToast(t);
      expect(errors, isEmpty);
    });

    testWidgets('contact: required name, and server field errors appear on the field', (t) async {
      final repo = FakeAdminRepository()..cmsError = _invalid({'email': 'Format email tidak valid.'});
      await _boot(t, repo);
      await _openMenu(t, 'Kelola FAQ & Kontak');

      await t.enterText(find.byType(TextField).at(0), '');
      await t.pump();
      await _tap(t, find.widgetWithText(CustomButton, 'Simpan Kontak'));
      expect(find.text('Kolom ini wajib diisi.'), findsOneWidget);
      expect(repo.cmsCalls, isEmpty);

      await t.enterText(find.byType(TextField).at(0), 'SDN 02 Pakunden');
      await t.enterText(find.byType(TextField).at(6), 'salah');
      await t.pump();
      await _tap(t, find.widgetWithText(CustomButton, 'Simpan Kontak'));
      expect(find.text('Format email tidak valid.'), findsOneWidget);
      await _drainToast(t);
      expect(errors, isEmpty);
    });

    testWidgets('faq: validation, add, edit and delete', (t) async {
      final repo = FakeAdminRepository();
      await _boot(t, repo);
      await _openMenu(t, 'Kelola FAQ & Kontak');
      expect(find.text('Kapan PPDB dibuka?'), findsOneWidget);

      await _tap(t, find.text('+ Tambah Pertanyaan'));
      await _tap(t, _inDialog('Tambah'));
      expect(find.text('Kolom ini wajib diisi.'), findsNWidgets(2));

      await t.enterText(_dialogFields().at(0), 'Jam masuk?');
      await t.enterText(_dialogFields().at(1), 'Pukul 07.00.');
      await _tap(t, _inDialog('Tambah'));
      expect(repo.cmsFaqs.last.pertanyaan, 'Jam masuk?');
      expect(repo.cmsFaqs.last.urutan, 2);
      expect(find.text('Jam masuk?'), findsOneWidget);
      await _drainToast(t);

      await _tap(t, find.text('Edit').last);
      await t.enterText(_dialogFields().at(1), 'Pukul 06.45.');
      await _tap(t, _inDialog('Simpan'));
      expect(repo.cmsFaqs.last.jawaban, 'Pukul 06.45.');
      await _drainToast(t);

      await _tap(t, find.text('Hapus').first);
      await _tap(t, _inDialog('Hapus'));
      expect(find.text('Kapan PPDB dibuka?'), findsNothing);
      await _drainToast(t);
      expect(errors, isEmpty);
    });
  });
}
