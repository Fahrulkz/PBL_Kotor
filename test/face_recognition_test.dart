import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aplikasi_guru/core/camera.dart';
import 'package:aplikasi_guru/core/network/api_exception.dart';
import 'package:aplikasi_guru/core/theme.dart';
import 'package:aplikasi_guru/features/guru/providers/face_scan_provider.dart';
import 'package:aplikasi_guru/features/guru/screens/face_recognition_screen.dart';
import 'package:aplikasi_guru/features/guru/widgets/face_oval_overlay.dart';
import 'package:aplikasi_guru/models/app_models.dart';
import 'package:aplikasi_guru/providers/app_providers.dart';
import 'package:aplikasi_guru/repositories/guru_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/fakes.dart';

class _FakeCamera implements FaceCamera {
  _FakeCamera({this.initError});

  final CameraUnavailable? initError;
  var disposed = false;

  @override
  Future<void> initialize() async {
    if (initError != null) throw initError!;
  }

  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(key: Key('preview'), color: Color(0xFF334455));

  @override
  Future<Uint8List> capture() async => Uint8List.fromList([1, 2, 3]);

  @override
  Future<void> dispose() async => disposed = true;
}

Future<_FakeCamera> _pump(
  WidgetTester t, {
  CameraUnavailable? initError,
  FaceScanner? scanner,
  FakeGuruRepository? guru,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  final camera = _FakeCamera(initError: initError);
  final container = ProviderContainer(overrides: [
    faceCameraFactoryProvider.overrideWithValue(() => camera),
    if (scanner != null) faceScannerProvider.overrideWithValue(scanner),
    if (guru != null) guruRepositoryProvider.overrideWithValue(guru),
  ]);
  addTearDown(container.dispose);
  container.read(selectedClassProvider.notifier).select('5A');

  await t.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.light,
      home: const FaceRecognitionScreen(startAtPermission: false),
    ),
  ));
  await t.pump();
  await t.pump();
  return camera;
}

void main() {
  final errors = <FlutterErrorDetails>[];
  setUp(() {
    errors.clear();
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.exceptionAsString().contains('google_fonts')) errors.add(d);
    };
    addTearDown(() => FlutterError.onError = original);
  });

  testWidgets('shows preview, overlay, instruction and no demo dropdown', (t) async {
    await _pump(t);

    expect(find.byKey(const Key('preview')), findsOneWidget);
    expect(find.byType(FaceOvalOverlay), findsOneWidget);
    expect(find.text('Posisikan wajah siswa di dalam area.'), findsOneWidget);
    expect(find.text('Mulai Scan'), findsOneWidget);
    expect(find.textContaining('Simulasi'), findsNothing);
    expect(find.byType(DropdownButtonFormField<dynamic>), findsNothing);
    expect(errors, isEmpty);
  });

  testWidgets('default scanner sends the photo to the repository and shows the result', (t) async {
    final guru = FakeGuruRepository()
      ..faceResult = const FaceMatched(studentId: 3, studentName: 'Dimas Arya', time: '07:41');
    await _pump(t, guru: guru);

    await t.tap(find.text('Mulai Scan'));
    await t.pump();
    await t.pump();
    expect(guru.faceScans, hasLength(1));
    expect(guru.faceScans.single.$1, '5A');
    expect(guru.faceScans.single.$2, [1, 2, 3]);
    expect(find.text('Absensi Berhasil dicatat'), findsOneWidget);
    expect(find.text('Dimas Arya'), findsWidgets);
    expect(find.text('Scan tidak dapat diproses'), findsNothing);
    expect(errors, isEmpty);
  });

  testWidgets('default scanner reloads the class so attendance reflects the scan', (t) async {
    final guru = FakeGuruRepository();
    final container = ProviderContainer(overrides: [
      guruRepositoryProvider.overrideWithValue(guru),
    ]);
    addTearDown(container.dispose);
    await container.read(classDataAsyncProvider('5A').future);
    guru.faceResult = const FaceMatched(studentId: 3, studentName: 'Dimas Arya', time: '07:41');
    var loads = 0;
    container.listen(classDataAsyncProvider('5A'), (_, _) => loads++);

    final result = await container.read(faceScannerProvider)('5A', Uint8List.fromList([9]));

    expect(result, isA<FaceMatched>());
    expect(loads, greaterThan(0));
  });

  testWidgets('a server error during the scan is shown with its message', (t) async {
    final guru = FakeGuruRepository()
      ..faceError = const ApiException(
        type: ApiErrorType.forbidden,
        message: 'Hanya guru mapel kelas ini yang dapat mencatat absensi dan nilai.',
        statusCode: 403,
      );
    await _pump(t, guru: guru);

    await t.tap(find.text('Mulai Scan'));
    await t.pump();
    await t.pump();

    expect(find.text('Scan tidak dapat diproses'), findsOneWidget);
    expect(find.textContaining('Hanya guru mapel'), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('scanner receives the captured photo and class', (t) async {
    Uint8List? sentImage;
    String? sentClass;
    final done = Completer<FaceScanResult>();
    await _pump(t, scanner: (cls, image) {
      sentClass = cls;
      sentImage = image;
      return done.future;
    });

    await t.tap(find.text('Mulai Scan'));
    await t.pump();
    expect(sentImage, [1, 2, 3]);
    expect(sentClass, '5A');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Memindai wajah…'), findsOneWidget);

    done.complete(const FaceMatched(studentId: 7, studentName: 'Dimas Arya', time: '07:41'));
    await t.pump();
    await t.pump();
    expect(find.text('Dimas Arya'), findsWidgets);
    expect(find.text('07:41'), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('unrecognised face offers retry back to the camera', (t) async {
    await _pump(t, scanner: (_, _) async => const FaceNotRecognized());

    await t.tap(find.text('Mulai Scan'));
    await t.pump();
    await t.pump();
    expect(find.text('Wajah Belum Terdaftar'), findsOneWidget);
    expect(find.text('Wajah belum dikenali'), findsNothing);

    await t.tap(find.text('Coba Lagi'));
    await t.pump();
    expect(find.text('Mulai Scan'), findsOneWidget);
    expect(find.byKey(const Key('preview')), findsOneWidget);
    expect(errors, isEmpty);
  });

  testWidgets('camera permission denied shows the reason and no scan button', (t) async {
    await _pump(t, initError: const CameraPermissionDenied());

    expect(find.text('Scan tidak dapat diproses'), findsOneWidget);
    expect(find.textContaining('Izin kamera ditolak'), findsOneWidget);
    expect(find.text('Mulai Scan'), findsNothing);
    expect(errors, isEmpty);
  });

  testWidgets('camera is released when the screen closes', (t) async {
    final camera = await _pump(t);
    await t.pumpWidget(const SizedBox());
    expect(camera.disposed, isTrue);
  });

  testWidgets('overlay is dim around the oval and transparent inside it', (t) async {
    await t.runAsync(() async {
      const size = Size(400, 800);
      final recorder = ui.PictureRecorder();
      const FaceOvalOverlayPainter().paint(Canvas(recorder), size);
      final image = await recorder.endRecording().toImage(400, 800);
      final data = (await image.toByteData())!;

      int alphaAt(double x, double y) =>
          data.getUint8((y.round() * 400 + x.round()) * 4 + 3);

      final oval = faceOvalRect(size);
      expect(oval.height / oval.width, closeTo(210 / 160, 0.01));
      expect(alphaAt(oval.center.dx, oval.center.dy), 0);
      expect(alphaAt(oval.center.dx, oval.top + oval.height * 0.3), 0);
      expect(alphaAt(2, 2), greaterThan(100));
      expect(alphaAt(oval.right + 20, oval.center.dy), greaterThan(100));
    });
  });
}
