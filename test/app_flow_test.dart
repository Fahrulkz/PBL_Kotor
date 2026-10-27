import 'package:aplikasi_guru/main.dart';
import 'package:aplikasi_guru/models/app_models.dart';
import 'package:aplikasi_guru/repositories/auth_repository.dart';
import 'package:aplikasi_guru/repositories/guru_repository.dart';
import 'package:aplikasi_guru/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/test_env.dart';

typedef _Env = ({FakeAuthRepository auth, FakeGuruRepository guru});

Future<_Env> _boot(WidgetTester t) async {
  await prepareFonts();
  t.view.physicalSize = const Size(780, 1688);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);

  final auth = FakeAuthRepository();
  final guru = FakeGuruRepository();
  await t.pumpWidget(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      guruRepositoryProvider.overrideWithValue(guru),
    ],
    child: const AplikasiGuruApp(),
  ));
  await t.pumpAndSettle();
  return (auth: auth, guru: guru);
}

Future<void> _login(
  WidgetTester t, {
  required String role,
  required String email,
  String password = 'Guru12345',
}) async {
  await t.tap(find.text(role));
  await t.pump();
  await t.enterText(find.byType(TextField).at(0), email);
  await t.enterText(find.byType(TextField).at(1), password);
  await t.tap(find.text('Masuk').last);
  await t.pumpAndSettle();
}

Future<void> _drainToast(WidgetTester t) => t.pump(const Duration(seconds: 3));

void main() {
  final errors = captureErrors();

  testWidgets('login: required fields, no demo button, wrong credentials', (t) async {
    await _boot(t);
    expect(find.text('Isi akun demo'), findsNothing);

    await t.tap(find.text('Masuk').last);
    await t.pump();
    expect(find.text('Kolom ini wajib diisi.'), findsNWidgets(2));

    await _login(t, role: 'Guru Mapel', email: 'x@contoh.id', password: 'salah');
    expect(find.text('Email atau password tidak sesuai.'), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('guru mapel: manual attendance and add grade reach the repository', (t) async {
    final env = await _boot(t);
    await _login(t, role: 'Guru Mapel', email: 'pak.andi@contoh.id');

    expect(find.text('Selamat pagi, Pak Andi'), findsOneWidget);
    expect(find.text('Ringkasan hari ini'), findsOneWidget);
    expect(find.text('Data contoh'), findsNothing);

    await t.tap(find.text('Absen').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Kelas 5A'));
    await t.pumpAndSettle();
    expect(find.text('Absensi Kelas 5A'), findsOneWidget);

    await t.tap(find.text('Input Manual'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(CustomButton, 'Sakit'));
    await t.pumpAndSettle();
    expect(env.guru.attendanceCalls, [(1, AttendanceStatus.sakit, '')]);
    await _drainToast(t);

    await t.tap(find.text('Kelas').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Nilai'));
    await t.pumpAndSettle();
    await t.tap(find.text('+ Tambah Nilai'));
    await t.pumpAndSettle();
    await t.tap(find.text('Simpan Nilai'));
    await t.pump();
    expect(find.text('Nilai wajib diisi.'), findsOneWidget);

    await t.enterText(find.byType(TextField).at(0), '88');
    await t.tap(find.text('Simpan Nilai'));
    await t.pumpAndSettle();
    expect(env.guru.createdGrades.single.value, 88);
    expect(env.guru.createdGrades.single.studentId, 1);
    await _drainToast(t);
    expect(errors, isEmpty);
  });

  testWidgets('wali kelas is view-only', (t) async {
    await _boot(t);
    await _login(t, role: 'Wali Kelas', email: 'bu.rina@contoh.id');

    expect(find.textContaining('Wali Kelas 5A'), findsWidgets);
    await t.tap(find.text('Hadir').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Kelas 5A'));
    await t.pumpAndSettle();
    expect(find.textContaining('Mode lihat'), findsOneWidget);
    expect(find.text('Mulai Face Recognition'), findsNothing);
    expect(errors, isEmpty);
  });

  testWidgets('temporary password must be changed before continuing', (t) async {
    final env = await _boot(t);
    await _login(t, role: 'Guru Mapel', email: 'guru.baru@contoh.id');
    expect(find.text('Ganti password'), findsOneWidget);

    await t.enterText(find.byType(TextField).at(0), 'abc');
    await t.enterText(find.byType(TextField).at(1), 'abd');
    await t.tap(find.text('Simpan dan Lanjut'));
    await t.pump();
    expect(find.text('Minimal 8 karakter.'), findsOneWidget);
    expect(find.text('Password tidak sama.'), findsOneWidget);

    await t.enterText(find.byType(TextField).at(0), 'PasswordBaru1');
    await t.enterText(find.byType(TextField).at(1), 'PasswordBaru1');
    await t.tap(find.text('Simpan dan Lanjut'));
    await t.pumpAndSettle();
    expect(env.auth.changedPassword, 'PasswordBaru1');
    expect(find.text('Selamat pagi, Guru Baru'), findsOneWidget);
    await _drainToast(t);
    expect(errors, isEmpty);
  });

  testWidgets('profile shows NIP and the late limit from the session, no placeholders', (t) async {
    final env = await _boot(t);
    await _login(t, role: 'Guru Mapel', email: 'pak.andi@contoh.id');

    await t.tap(find.text('PA'));
    await t.pumpAndSettle();
    expect(find.text('NIP: 198501012010011001'), findsOneWidget);
    expect(find.text('Pukul 07:15'), findsOneWidget);
    expect(find.textContaining('['), findsNothing);
    expect(env.auth.loggedOut, isFalse);
    expect(errors, isEmpty);
  });

  testWidgets('profile falls back cleanly when NIP and late limit are not set', (t) async {
    final env = await _boot(t);
    env.auth.lateLimit = null;
    await _login(t, role: 'Wali Kelas', email: 'bu.rina@contoh.id');

    await t.tap(find.text('BR'));
    await t.pumpAndSettle();
    expect(find.text('NIP: —'), findsOneWidget);
    expect(find.text('Belum diatur'), findsOneWidget);
    expect(find.textContaining('['), findsNothing);
    expect(errors, isEmpty);
  });

  testWidgets('logging out calls the server and returns to the login screen', (t) async {
    final env = await _boot(t);
    await _login(t, role: 'Guru Mapel', email: 'pak.andi@contoh.id');

    await t.tap(find.text('PA'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(CustomButton, 'Keluar'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(CustomButton, 'Keluar').last);
    await t.pumpAndSettle();

    expect(env.auth.loggedOut, isTrue);
    expect(find.text('Masuk sebagai'), findsOneWidget);
    await _drainToast(t);
    expect(errors, isEmpty);
  });
}
