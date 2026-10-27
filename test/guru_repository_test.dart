import 'dart:convert';
import 'dart:typed_data';

import 'package:aplikasi_guru/core/network/api_client.dart';
import 'package:aplikasi_guru/core/network/api_exception.dart';
import 'package:aplikasi_guru/core/network/token_storage.dart';
import 'package:aplikasi_guru/models/app_models.dart';
import 'package:aplikasi_guru/repositories/guru_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorded {
  _Recorded(this.options, this.body);
  final RequestOptions options;
  final String body;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.json);

  final int status;
  final Map<String, dynamic> json;
  final requests = <_Recorded>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    requests.add(_Recorded(options, latin1.decode(bytes)));
    return ResponseBody.fromString(
      jsonEncode(json),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(ApiGuruRepository, _Adapter)> _repo(int status, Map<String, dynamic> json) async {
  final adapter = _Adapter(status, json);
  final tokens = MemoryTokenStorage();
  await tokens.write('tok-123');
  final dio = Dio()..httpClientAdapter = adapter;
  final api = ApiClient(tokens: tokens, dio: dio, baseUrl: 'http://api.test/api/v1');
  return (ApiGuruRepository(api), adapter);
}

Future<FaceScanResult> _scan(ApiGuruRepository repo) =>
    repo.recognizeFace(classCode: '5A', image: Uint8List.fromList([1, 2, 3]));

void main() {
  test('face scan posts the photo as multipart field "foto" with the bearer token', () async {
    final (repo, adapter) = await _repo(200, {'hasil': 'tidak_dikenali'});

    await _scan(repo);

    final sent = adapter.requests.single;
    expect(sent.options.method, 'POST');
    expect(sent.options.uri.toString(), 'http://api.test/api/v1/guru/classes/5A/attendance/face');
    expect(sent.options.headers['Authorization'], 'Bearer tok-123');
    expect(sent.options.contentType, startsWith('multipart/form-data'));
    expect(sent.body, contains('name="foto"'));
    expect(sent.body, contains('filename="scan.jpg"'));
  });

  test('hasil "cocok" becomes FaceMatched with the HH:mm time', () async {
    final (repo, _) = await _repo(200, {
      'hasil': 'cocok',
      'kode': null,
      'pesan': null,
      'siswa_id': 7,
      'nama': 'Ahmad Rizky',
      'kelas': '5A',
      'waktu': '07:41:05',
      'status': 'H',
    });

    final result = await _scan(repo);

    expect(result, isA<FaceMatched>());
    final matched = result as FaceMatched;
    expect((matched.studentId, matched.studentName, matched.time), (7, 'Ahmad Rizky', '07:41'));
  });

  test('hasil "duplikat" becomes FaceDuplicate', () async {
    final (repo, _) = await _repo(200, {
      'hasil': 'duplikat',
      'kode': 'FaceDuplicate',
      'siswa_id': 7,
      'nama': 'Ahmad Rizky',
      'kelas': '5A',
      'waktu': '07:41:05',
    });

    final result = await _scan(repo);

    expect(result, isA<FaceDuplicate>());
    expect((result as FaceDuplicate).time, '07:41');
  });

  test('hasil "kelas_lain" becomes FaceOtherClass', () async {
    final (repo, _) = await _repo(200, {'hasil': 'kelas_lain', 'kode': 'FaceOtherClass'});

    expect(await _scan(repo), isA<FaceOtherClass>());
  });

  test('FaceNotRecognized comes back as a normal 200 result, not an exception', () async {
    final (repo, _) = await _repo(200, {
      'hasil': 'tidak_dikenali',
      'kode': 'FaceNotRecognized',
      'pesan': 'Wajah belum terdaftar. Minta wali kelas mendaftarkan wajah siswa.',
    });

    expect(await _scan(repo), isA<FaceNotRecognized>());
  });

  test('a 403 from the server surfaces as ApiException with the server message', () async {
    final (repo, _) = await _repo(403, {
      'message': 'Hanya guru mapel kelas ini yang dapat mencatat absensi dan nilai.',
    });

    await expectLater(
      _scan(repo),
      throwsA(
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.forbidden)
            .having((e) => e.message, 'message', contains('Hanya guru mapel')),
      ),
    );
  });

  test('class detail response from the backend parses into ClassData', () async {
    final (repo, _) = await _repo(200, {
      'siswa': [
        {
          'id': 1,
          'nama': 'Ahmad Rizky',
          'klasifikasi': 'Perlu Pendampingan',
          'status': null,
          'waktu': null,
          'literasi': 75,
          'numerasi': 0,
          'menurun': true,
        },
      ],
      'nilai': [
        {
          'id': 4,
          'siswa_id': 1,
          'siswa': 'Ahmad Rizky',
          'kategori': 'Literasi',
          'jenis_ujian': 'Ulangan',
          'nilai': 70.0,
          'nilai_sebelumnya': 80.0,
          'tanggal': '2026-10-05',
          'catatan_guru': null,
        },
      ],
      'rata_literasi': 73,
      'rata_numerasi': 0,
      'tren': {
        'literasi': [75, 71],
        'numerasi': <int>[],
        'kehadiran': [50],
      },
    });

    final data = await repo.fetchClassData('5A');

    expect(data.students.single.classification, Classification.perlu);
    expect(data.students.single.declining, isTrue);
    expect((data.grades.single.value, data.grades.single.previous), (70, 80));
    expect(data.grades.single.note, '');
    expect(data.literasiTrend, [75, 71]);
    expect(data.attendanceTrend, [50]);
  });
}
