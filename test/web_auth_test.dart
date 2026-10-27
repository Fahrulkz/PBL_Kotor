import 'package:aplikasi_guru/core/network/api_client.dart';
import 'package:aplikasi_guru/features/admin/screens/admin_main_layout.dart';
import 'package:aplikasi_guru/features/orang_tua/screens/parent_main_layout.dart';
import 'package:aplikasi_guru/features/web_auth/providers/web_session_provider.dart';
import 'package:aplikasi_guru/features/website/screens/website_main_layout.dart';
import 'package:aplikasi_guru/main_website.dart';
import 'package:aplikasi_guru/repositories/admin_repository.dart';
import 'package:aplikasi_guru/repositories/parent_repository.dart';
import 'package:aplikasi_guru/repositories/web_auth_repository.dart';
import 'package:aplikasi_guru/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/test_env.dart';
import 'support/web_fakes.dart';

typedef _Env = ({
  FakeWebAuthRepository auth,
  FakeParentRepository parent,
  ProviderContainer container,
});

Future<_Env> _boot(WidgetTester t) async {
  await prepareFonts();
  t.view.physicalSize = const Size(1500, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  final auth = FakeWebAuthRepository();
  final parent = FakeParentRepository();
  await t.pumpWidget(ProviderScope(
    overrides: [
      webAuthRepositoryProvider.overrideWithValue(auth),
      parentRepositoryProvider.overrideWithValue(parent),
      adminRepositoryProvider.overrideWithValue(FakeAdminRepository()),
    ],
    child: const WebsiteApp(),
  ));
  await t.pumpAndSettle();
  return (
    auth: auth,
    parent: parent,
    container: ProviderScope.containerOf(t.element(find.byType(WebsiteMainLayout))),
  );
}

Future<void> _fillAndSubmit(WidgetTester t, String email, [String? password]) async {
  await t.enterText(find.byType(TextField).at(0), email);
  await t.enterText(find.byType(TextField).at(1), password ?? FakeWebAuthRepository.password);
  await t.tap(find.widgetWithText(CustomButton, 'Masuk'));
  await t.pumpAndSettle();
}

Future<void> _openParentLogin(WidgetTester t) async {
  await t.tap(find.descendant(of: find.byType(AppBar), matching: find.text('Login Orang Tua')));
  await t.pumpAndSettle();
}

Future<void> _openAdminLogin(WidgetTester t) async {
  await t.ensureVisible(find.text('Login Admin'));
  await t.pumpAndSettle();
  await t.tap(find.text('Login Admin'));
  await t.pumpAndSettle();
}

Future<void> _confirmLogout(WidgetTester t) async {
  await t.tap(find.text('Keluar').first);
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(CustomButton, 'Keluar'));
  await t.pumpAndSettle();
  await t.pump(const Duration(seconds: 3));
}

void main() {
  final errors = captureErrors();

  testWidgets('parent: header button opens login, wrong credentials are rejected', (t) async {
    final env = await _boot(t);
    await _openParentLogin(t);
    expect(find.text('Portal Orang Tua'), findsOneWidget);
    expect(find.text('Lupa password?'), findsOneWidget);

    await t.tap(find.widgetWithText(CustomButton, 'Masuk'));
    await t.pump();
    expect(find.text('Kolom ini wajib diisi.'), findsNWidgets(2));

    await _fillAndSubmit(t, 'orangtua@contoh.id', 'salah');
    expect(find.text('Email atau password tidak sesuai.'), findsOneWidget);
    expect(find.byType(ParentMainLayout), findsNothing);
    expect(env.container.read(webSessionProvider).status, WebAuthStatus.signedOut);
    expect(errors, isEmpty);
  });

  testWidgets('parent: successful login lands on the parent portal, logout returns', (t) async {
    final env = await _boot(t);
    await _openParentLogin(t);
    await _fillAndSubmit(t, 'OrangTua@Contoh.id ');

    expect(env.auth.loginAttempts, ['orangtua@contoh.id']);
    expect(find.byType(ParentMainLayout), findsOneWidget);
    expect(find.text('Perkembangan Anak'), findsOneWidget);
    expect(find.byType(WebsiteMainLayout), findsNothing);
    expect(find.text('Kembali ke Website'), findsNothing);

    await _confirmLogout(t);
    expect(env.auth.logoutCount, 1);
    expect(find.byType(WebsiteMainLayout), findsOneWidget);
    expect(find.byType(ParentMainLayout), findsNothing);
    expect(errors, isEmpty);
  });

  testWidgets('admin: footer link opens the admin login, parents are refused', (t) async {
    final env = await _boot(t);
    await _openAdminLogin(t);
    expect(find.text('Panel Admin'), findsOneWidget);
    expect(find.text('Lupa password?'), findsNothing);

    await _fillAndSubmit(t, 'orangtua@contoh.id');
    expect(find.text('Akun ini tidak memiliki akses ke halaman ini.'), findsOneWidget);
    expect(env.container.read(webSessionProvider).status, WebAuthStatus.signedOut);

    await _fillAndSubmit(t, 'admin@contoh.id');
    expect(find.byType(AdminMainLayout), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Admin Sekolah'), findsWidgets);

    await t.tap(find.descendant(of: find.byType(AdminSidebar), matching: find.text('Keluar')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(CustomButton, 'Keluar'));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 3));
    expect(find.byType(WebsiteMainLayout), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('an admin account cannot enter through the parent login', (t) async {
    final env = await _boot(t);
    await _openParentLogin(t);
    await _fillAndSubmit(t, 'admin@contoh.id');
    expect(find.text('Akun ini tidak memiliki akses ke halaman ini.'), findsOneWidget);
    expect(env.container.read(webSessionProvider).status, WebAuthStatus.signedOut);
    expect(errors, isEmpty);
  });

  testWidgets('temporary password must be changed, then the portal opens', (t) async {
    final env = await _boot(t);
    await _openParentLogin(t);
    await _fillAndSubmit(t, 'ortu.baru@contoh.id');

    expect(find.text('Ganti password'), findsOneWidget);
    expect(find.byType(ParentMainLayout), findsNothing);

    await t.enterText(find.byType(TextField).at(0), 'abc');
    await t.enterText(find.byType(TextField).at(1), 'abd');
    await t.tap(find.widgetWithText(CustomButton, 'Simpan dan Lanjut'));
    await t.pump();
    expect(find.text('Minimal 8 karakter.'), findsOneWidget);
    expect(find.text('Password tidak sama.'), findsOneWidget);

    await t.enterText(find.byType(TextField).at(0), 'PasswordBaru1');
    await t.enterText(find.byType(TextField).at(1), 'PasswordBaru1');
    await t.tap(find.widgetWithText(CustomButton, 'Simpan dan Lanjut'));
    await t.pumpAndSettle();
    expect(env.auth.changedPassword, 'PasswordBaru1');
    expect(find.byType(ParentMainLayout), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(errors, isEmpty);
  });

  testWidgets('cancelling the forced password change signs out', (t) async {
    final env = await _boot(t);
    await _openParentLogin(t);
    await _fillAndSubmit(t, 'ortu.baru@contoh.id');
    await t.tap(find.widgetWithText(CustomButton, 'Batal dan Keluar'));
    await t.pumpAndSettle();
    expect(env.auth.logoutCount, 1);
    expect(find.byType(WebsiteMainLayout), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('forgot password sends the request and confirms', (t) async {
    final env = await _boot(t);
    await _openParentLogin(t);
    await t.tap(find.text('Lupa password?'));
    await t.pumpAndSettle();

    await t.tap(find.widgetWithText(CustomButton, 'Kirim Tautan'));
    await t.pump();
    expect(find.text('Kolom ini wajib diisi.'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'orangtua@contoh.id');
    await t.tap(find.widgetWithText(CustomButton, 'Kirim Tautan'));
    await t.pumpAndSettle();
    expect(env.auth.resetRequests, ['orangtua@contoh.id']);
    expect(find.text('Tautan pemulihan telah dikirim'), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('the next user never sees the previous user\'s cached data', (t) async {
    final env = await _boot(t);
    await _openParentLogin(t);
    await _fillAndSubmit(t, 'orangtua@contoh.id');
    expect(env.parent.childrenFetches, 1);

    await _confirmLogout(t);
    await _openParentLogin(t);
    await _fillAndSubmit(t, 'ortu.lain@contoh.id');
    expect(find.byType(ParentMainLayout), findsOneWidget);
    expect(env.parent.childrenFetches, 2);
    expect(errors, isEmpty);
  });

  testWidgets('an expired session returns to the website with a notice', (t) async {
    final env = await _boot(t);
    await _openParentLogin(t);
    await _fillAndSubmit(t, 'orangtua@contoh.id');
    expect(find.byType(ParentMainLayout), findsOneWidget);

    env.container.read(sessionExpiredProvider.notifier).notify();
    await t.pumpAndSettle();
    expect(find.byType(WebsiteMainLayout), findsOneWidget);
    expect(find.text('Sesi Anda telah berakhir. Silakan masuk kembali.'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(errors, isEmpty);
  });

  testWidgets('back to website leaves the login page', (t) async {
    await _boot(t);
    await _openParentLogin(t);
    await t.tap(find.widgetWithText(CustomButton, 'Kembali ke Website'));
    await t.pumpAndSettle();
    expect(find.byType(WebsiteMainLayout), findsOneWidget);
    expect(find.text('Lupa password?'), findsNothing);
    expect(errors, isEmpty);
  });
}
