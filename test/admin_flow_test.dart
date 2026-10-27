import 'package:aplikasi_guru/core/network/api_exception.dart';
import 'package:aplikasi_guru/features/admin/providers/admin_providers.dart';
import 'package:aplikasi_guru/features/admin/screens/admin_main_layout.dart';
import 'package:aplikasi_guru/repositories/admin_repository.dart';
import 'package:aplikasi_guru/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';
import 'support/test_env.dart';

Future<ProviderContainer> _boot(
  WidgetTester t,
  FakeAdminRepository repo, {
  Size size = const Size(1400, 1000),
}) async {
  await prepareFonts();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [adminRepositoryProvider.overrideWithValue(repo)],
    child: harnessApp(const AdminMainLayout()),
  ));
  await t.pumpAndSettle();
  return ProviderScope.containerOf(t.element(find.byType(AdminMainLayout)));
}

Future<void> _openMenu(WidgetTester t, String label) async {
  await t.tap(find.descendant(of: find.byType(AdminSidebar), matching: find.text(label)));
  await t.pumpAndSettle();
}

Future<void> _drainToast(WidgetTester t) => t.pump(const Duration(seconds: 3));

void main() {
  final errors = captureErrors();

  testWidgets('dashboard reads counts from the repository and navigates', (t) async {
    await _boot(t, FakeAdminRepository());
    expect(find.text('Perlu tindakan'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('1 kelas belum punya wali kelas'), findsOneWidget);
    expect(find.text('Sistem dimulai'), findsOneWidget);

    await t.tap(find.text('0 akun nonaktif'));
    await t.pumpAndSettle();
    expect(find.text('Akun tidak ditemukan.'), findsOneWidget);

    await _openMenu(t, 'Log Aktivitas');
    expect(find.text('Sistem dimulai'), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('load failure shows a retry that recovers', (t) async {
    final repo = FakeAdminRepository()
      ..failFetch = apiError('Server tidak merespons.', type: ApiErrorType.server);
    await _boot(t, repo);
    expect(find.text('Data belum dapat dimuat.'), findsOneWidget);
    expect(find.text('Server tidak merespons.'), findsOneWidget);

    repo.failFetch = null;
    await t.tap(find.text('Coba Lagi'));
    await t.pumpAndSettle();
    expect(find.text('Perlu tindakan'), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('accounts: add guru, validation, deactivate, delete', (t) async {
    final repo = FakeAdminRepository();
    await _boot(t, repo);
    await _openMenu(t, 'Manajemen Akun');

    await t.tap(find.text('+ Tambah Akun'));
    await t.pumpAndSettle();
    await t.tap(find.text('Buat Akun'));
    await t.pump();
    expect(find.text('Kolom ini wajib diisi.'), findsNWidgets(2));

    await t.enterText(find.byType(TextField).at(1), 'Guru Baru');
    await t.enterText(find.byType(TextField).at(2), 'bu.rina@contoh.id');
    await t.tap(find.text('Buat Akun'));
    await t.pump();
    expect(find.text('Email sudah dipakai akun lain.'), findsOneWidget);

    await t.enterText(find.byType(TextField).at(2), 'guru.baru@contoh.id');
    await t.tap(find.text('Buat Akun'));
    await t.pumpAndSettle();
    expect(find.text('Akun siap dipakai'), findsOneWidget);
    expect(find.textContaining('guru.baru@contoh.id'), findsWidgets);
    expect(find.textContaining('Sdn-temp-'), findsWidgets);
    await t.tap(find.text('Selesai'));
    await t.pumpAndSettle();
    expect(repo.guru.length, 4);

    await t.enterText(find.byType(TextField).first, 'guru.baru');
    await t.pumpAndSettle();
    expect(find.text('Belum ganti password'), findsOneWidget);
    await t.tap(find.text('Nonaktifkan'));
    await t.pumpAndSettle();
    await t.tap(find.text('Nonaktifkan').last);
    await t.pumpAndSettle();
    expect(repo.guru.last.active, isFalse);

    await t.tap(find.text('Hapus'));
    await t.pumpAndSettle();
    final deleteButton = find.widgetWithText(CustomButton, 'Hapus Permanen');
    expect(t.widget<CustomButton>(deleteButton).onPressed, isNull);
    await t.enterText(find.byType(TextField).last, 'HAPUS');
    await t.pump();
    await t.tap(find.text('Hapus Permanen'));
    await t.pumpAndSettle();
    expect(repo.guru.length, 3);
    await _drainToast(t);
    expect(errors, isEmpty);
  });

  testWidgets('accounts: admin cannot deactivate or delete self', (t) async {
    await _boot(t, FakeAdminRepository());
    await _openMenu(t, 'Manajemen Akun');
    await t.tap(find.text('Admin (2)'));
    await t.pumpAndSettle();

    final nonaktif = find.widgetWithText(CustomButton, 'Nonaktifkan');
    final hapus = find.widgetWithText(CustomButton, 'Hapus');
    expect(nonaktif, findsNWidgets(2));
    expect(t.widget<CustomButton>(nonaktif.first).onPressed, isNull);
    expect(t.widget<CustomButton>(hapus.first).onPressed, isNull);
    expect(t.widget<CustomButton>(nonaktif.last).onPressed, isNotNull);
    expect(t.widget<CustomButton>(hapus.last).onPressed, isNotNull);
    expect(errors, isEmpty);
  });

  testWidgets('classes: select students and move them', (t) async {
    final repo = FakeAdminRepository();
    final container = await _boot(t, repo);
    await _openMenu(t, 'Struktur Kelas');

    await t.tap(find.text('Kelas 5A'));
    await t.pumpAndSettle();
    expect(find.text('Wali kelas'), findsOneWidget);
    expect(find.text('Bu Rina'), findsOneWidget);
    expect(find.text('Siswa (12)'), findsOneWidget);
    expect(find.text('Pindahkan terpilih (0)'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Pilih Ahmad Rizky'));
    await t.tap(find.bySemanticsLabel('Pilih Siti Aulia'));
    await t.pump();
    expect(find.text('Pindahkan terpilih (2)'), findsOneWidget);

    await t.tap(find.text('Pindahkan terpilih (2)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Lanjut'));
    await t.pump();
    expect(find.text('Kolom ini wajib diisi.'), findsOneWidget);

    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Kelas 5B (2 siswa)').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Lanjut'));
    await t.pumpAndSettle();
    expect(find.textContaining('Pindahkan 2 siswa dari 5A ke 5B?'), findsOneWidget);
    await t.tap(find.text('Pindahkan').last);
    await t.pumpAndSettle();

    expect(repo.siswa.where((s) => s.classCode == '5A').length, 10);
    expect(repo.siswa.where((s) => s.classCode == '5B').length, 4);
    expect(container.read(selectedStudentsProvider), isEmpty);
    await _drainToast(t);
    expect(errors, isEmpty);
  });

  testWidgets('classes: add class then delete the empty class', (t) async {
    final repo = FakeAdminRepository();
    final container = await _boot(t, repo);
    await _openMenu(t, 'Struktur Kelas');

    await t.tap(find.text('+ Tambah Kelas'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'x9');
    await t.tap(find.text('Tambah Kelas').last);
    await t.pump();
    expect(find.text('Gunakan format seperti 5C.'), findsOneWidget);
    await t.enterText(find.byType(TextField).last, '5c');
    await t.tap(find.text('Tambah Kelas').last);
    await t.pumpAndSettle();

    expect(repo.classes.containsKey('5C'), isTrue);
    expect(find.text('Belum ada wali kelas'), findsOneWidget);
    expect(find.text('Kelas ini belum memiliki siswa.'), findsOneWidget);

    await t.tap(find.text('Hapus Kelas'));
    await t.pumpAndSettle();
    await t.tap(find.text('Hapus Kelas').last);
    await t.pumpAndSettle();
    expect(repo.classes.containsKey('5C'), isFalse);
    expect(container.read(selectedClassCodeProvider), isNull);
    await _drainToast(t);
    expect(errors, isEmpty);
  });

  testWidgets('server error on a mutation is shown and nothing is changed', (t) async {
    final repo = FakeAdminRepository()
      ..failMutation = apiError('Kelas sudah ada di server.', type: ApiErrorType.conflict);
    final container = await _boot(t, repo);
    await _openMenu(t, 'Struktur Kelas');

    await t.tap(find.text('+ Tambah Kelas'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, '5C');
    await t.tap(find.text('Tambah Kelas').last);
    await t.pumpAndSettle();

    expect(find.text('Kelas sudah ada di server.'), findsOneWidget);
    expect(repo.classes.containsKey('5C'), isFalse);
    expect(container.read(selectedClassCodeProvider), isNull);
    await _drainToast(t);
    expect(errors, isEmpty);
  });

  testWidgets('assigning a wali requires choosing a guru', (t) async {
    await _boot(t, FakeAdminRepository());
    await _openMenu(t, 'Struktur Kelas');
    await t.tap(find.text('Kelas 6A'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tetapkan'));
    await t.pumpAndSettle();
    await t.tap(find.text('Simpan'));
    await t.pump();
    expect(find.text('Kolom ini wajib diisi.'), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('settings: password errors from server, save, and no demo reset', (t) async {
    final repo = FakeAdminRepository();
    await _boot(t, repo);
    await _openMenu(t, 'Pengaturan');

    expect(find.textContaining('demo'), findsNothing);
    expect(find.textContaining('Demo'), findsNothing);

    await t.tap(find.text('Ganti Password'));
    await t.pump();
    expect(find.text('Kolom ini wajib diisi.'), findsNWidgets(3));

    await t.enterText(find.byType(TextField).at(1), 'salah');
    await t.enterText(find.byType(TextField).at(2), 'PasswordBaru1');
    await t.enterText(find.byType(TextField).at(3), 'PasswordBaru1');
    await t.tap(find.text('Ganti Password'));
    await t.pumpAndSettle();
    expect(find.text('Password lama tidak sesuai.'), findsOneWidget);
    expect(repo.adminPassword, 'Admin12345');

    await t.enterText(find.byType(TextField).at(1), 'Admin12345');
    await t.tap(find.text('Ganti Password'));
    await t.pumpAndSettle();
    expect(repo.adminPassword, 'PasswordBaru1');
    await _drainToast(t);

    await t.enterText(find.byType(TextField).at(0), '07:30');
    await t.tap(find.text('Simpan Pengaturan'));
    await t.pumpAndSettle();
    expect(repo.late, '07:30');
    await _drainToast(t);
    expect(errors, isEmpty);
  });

  testWidgets('mobile: sidebar hidden behind a drawer', (t) async {
    await _boot(t, FakeAdminRepository(), size: const Size(390, 844));
    expect(find.byType(AdminSidebar), findsNothing);

    await t.tap(find.byTooltip('Buka menu'));
    await t.pumpAndSettle();
    expect(find.byType(AdminSidebar), findsOneWidget);

    await t.tap(
      find.descendant(of: find.byType(AdminSidebar), matching: find.text('Log Aktivitas')),
    );
    await t.pumpAndSettle();
    expect(find.byType(AdminSidebar), findsNothing);
    expect(find.text('Cari aktivitas'), findsOneWidget);
    expect(errors, isEmpty);
  });
}
