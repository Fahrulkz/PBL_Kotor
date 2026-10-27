import 'dart:convert';
import 'dart:typed_data';

import 'package:aplikasi_guru/core/network/api_client.dart';
import 'package:aplikasi_guru/core/network/api_exception.dart';
import 'package:aplikasi_guru/core/network/token_storage.dart';
import 'package:aplikasi_guru/features/admin/data/cms_models.dart';
import 'package:aplikasi_guru/repositories/admin_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sent {
  _Sent(this.options, this.body);

  final RequestOptions options;
  final String body;

  String get method => options.method;
  String get path => options.uri.path;
  Object? get json => options.data;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.reply);

  final int status;
  final Object? reply;
  final sent = <_Sent>[];

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
    sent.add(_Sent(options, latin1.decode(bytes)));
    return ResponseBody.fromString(
      reply == null ? '' : jsonEncode(reply),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(ApiAdminRepository, _Adapter)> _repo(Object? reply, {int status = 200}) async {
  final adapter = _Adapter(status, reply);
  final tokens = MemoryTokenStorage();
  await tokens.write('tok-admin');
  final api = ApiClient(
    tokens: tokens,
    dio: Dio()..httpClientAdapter = adapter,
    baseUrl: 'http://api.test/api/v1',
  );
  return (ApiAdminRepository(api), adapter);
}

Map<String, dynamic> _postJson({String slug = 'berita-baru', String status = 'terbit'}) => {
  'slug': slug,
  'kategori': 'Berita',
  'judul': 'Berita Baru',
  'ringkasan': 'Ringkas.',
  'gambar_url': '/media/a.jpg',
  'tanggal': '2026-10-08',
  'status': status,
  'diperbarui': '2026-10-08T07:41:05+07:00',
  'isi': 'Isi.',
};

void main() {
  test('every CMS call is authenticated and goes under /admin/cms', () async {
    final (repo, adapter) = await _repo([]);

    await repo.fetchPages();

    expect(adapter.sent.single.options.headers['Authorization'], 'Bearer tok-admin');
    expect(adapter.sent.single.path, '/api/v1/admin/cms/pages');
    expect(adapter.sent.single.method, 'GET');
  });

  group('teks halaman', () {
    test('fetchPages parses groups, labels and line hints', () async {
      final (repo, _) = await _repo([
        {'kunci': 'hero-title', 'label': 'Judul utama', 'grup': 'Beranda', 'baris': 2, 'isi': 'Halo'},
        {'kunci': 'visi', 'label': 'Visi', 'grup': 'Profil Sekolah', 'baris': 3, 'isi': ''},
      ]);

      final pages = await repo.fetchPages();

      expect(pages.map((p) => (p.kunci, p.grup, p.baris, p.isi)), [
        ('hero-title', 'Beranda', 2, 'Halo'),
        ('visi', 'Profil Sekolah', 3, ''),
      ]);
    });

    test('savePages PUTs only what it is given under "halaman" and returns the fresh list', () async {
      final (repo, adapter) = await _repo([
        {'kunci': 'visi', 'label': 'Visi', 'grup': 'Profil', 'baris': 3, 'isi': 'Baru'},
      ]);

      final pages = await repo.savePages({'visi': 'Baru'});

      expect(adapter.sent.single.method, 'PUT');
      expect(adapter.sent.single.path, '/api/v1/admin/cms/pages');
      expect(adapter.sent.single.json, {
        'halaman': {'visi': 'Baru'},
      });
      expect(pages.single.isi, 'Baru');
    });
  });

  group('profil sekolah', () {
    test('saveSchool sends every field (nulls clear them) and parses the normalised reply', () async {
      final (repo, adapter) = await _repo({
        'nama': 'SDN 02 Pakunden',
        'kota': 'Blitar',
        'npsn': null,
        'alamat': 'Jl. Mawar 1',
        'akreditasi': 'A',
        'telepon': null,
        'email': 'info@sekolah.id',
        'media_sosial': null,
        'whatsapp': '6281234567890',
        'peta_url': '/media/peta.png',
      });

      final saved = await repo.saveSchool(
        const CmsSchool(nama: 'SDN 02 Pakunden', kota: 'Blitar', whatsapp: '0812 3456 7890'),
      );

      expect(adapter.sent.single.method, 'PUT');
      expect(adapter.sent.single.path, '/api/v1/admin/cms/school');
      expect(adapter.sent.single.json, {
        'nama': 'SDN 02 Pakunden',
        'kota': 'Blitar',
        'npsn': null,
        'alamat': null,
        'akreditasi': null,
        'telepon': null,
        'email': null,
        'media_sosial': null,
        'whatsapp': '0812 3456 7890',
        'peta_url': null,
      });
      expect((saved.whatsapp, saved.alamat, saved.petaUrl), ('6281234567890', 'Jl. Mawar 1', '/media/peta.png'));
    });
  });

  group('berita & pengumuman', () {
    test('fetchPosts and fetchPost parse status and dates', () async {
      final (repo, adapter) = await _repo([_postJson(status: 'draft')]);

      final list = await repo.fetchPosts();

      expect(adapter.sent.single.path, '/api/v1/admin/cms/posts');
      expect((list.single.status, list.single.tanggal, list.single.gambarUrl), (
        ContentStatus.draft,
        DateTime(2026, 10, 8),
        '/media/a.jpg',
      ));

      final (repo2, adapter2) = await _repo(_postJson());
      final detail = await repo2.fetchPost('berita-baru');
      expect(adapter2.sent.single.path, '/api/v1/admin/cms/posts/berita-baru');
      expect(detail.isi, 'Isi.');
    });

    test('createPost POSTs the API field names and includes the date only when chosen', () async {
      final (repo, adapter) = await _repo(_postJson(), status: 201);

      await repo.createPost(
        CmsPostInput(
          judul: 'Berita Baru',
          kategori: 'Pengumuman',
          ringkasan: '',
          isi: 'Isi.',
          status: ContentStatus.terbit,
          gambarUrl: '/media/a.jpg',
          tanggal: DateTime(2026, 10, 8),
        ),
      );
      await repo.createPost(
        const CmsPostInput(
          judul: 'Tanpa Tanggal',
          kategori: 'Berita',
          ringkasan: '',
          isi: '',
          status: ContentStatus.draft,
        ),
      );

      expect(adapter.sent.first.method, 'POST');
      expect(adapter.sent.first.json, {
        'judul': 'Berita Baru',
        'kategori': 'Pengumuman',
        'ringkasan': '',
        'isi': 'Isi.',
        'gambar_url': '/media/a.jpg',
        'status': 'terbit',
        'tanggal': '2026-10-08',
      });
      final second = adapter.sent.last.json! as Map;
      expect(second.containsKey('tanggal'), isFalse);
      expect(second['gambar_url'], isNull);
      expect(second['status'], 'draft');
    });

    test('updatePost PUTs to the slug and deletePost DELETEs it', () async {
      final (repo, adapter) = await _repo(_postJson(slug: 'x'));

      await repo.updatePost(
        'x',
        const CmsPostInput(
          judul: 'J',
          kategori: 'Berita',
          ringkasan: '',
          isi: '',
          status: ContentStatus.arsip,
        ),
      );
      final (repo2, adapter2) = await _repo(null, status: 204);
      await repo2.deletePost('x');

      expect((adapter.sent.single.method, adapter.sent.single.path), ('PUT', '/api/v1/admin/cms/posts/x'));
      expect((adapter2.sent.single.method, adapter2.sent.single.path), ('DELETE', '/api/v1/admin/cms/posts/x'));
    });
  });

  group('kegiatan', () {
    test('create sends foto_urls in order and parses the reply', () async {
      final (repo, adapter) = await _repo({
        'slug': 'pramuka',
        'kategori': 'Ekstrakurikuler',
        'judul': 'Pramuka',
        'deskripsi': 'Setiap pekan.',
        'tanggal': '2026-10-03',
        'status': 'terbit',
        'foto_urls': ['/media/a.jpg', 'https://x.id/b.png'],
      }, status: 201);

      final created = await repo.createActivity(
        const CmsActivityInput(
          judul: 'Pramuka',
          kategori: 'Ekstrakurikuler',
          deskripsi: 'Setiap pekan.',
          status: ContentStatus.terbit,
          fotoUrls: ['/media/a.jpg', 'https://x.id/b.png'],
        ),
      );

      expect(adapter.sent.single.path, '/api/v1/admin/cms/kegiatan');
      expect((adapter.sent.single.json! as Map)['foto_urls'], ['/media/a.jpg', 'https://x.id/b.png']);
      expect(created.fotoUrls, ['/media/a.jpg', 'https://x.id/b.png']);
    });
  });

  group('fasilitas & faq', () {
    test('facility: order is sent only when given, and ids go in the path', () async {
      final json = {
        'id': 7,
        'nama': 'Lapangan',
        'deskripsi': '',
        'gambar_url': null,
        'urutan': 3,
        'tampil': false,
      };
      final (repo, adapter) = await _repo(json, status: 201);

      await repo.createFacility(const CmsFacilityInput(nama: 'Lapangan', deskripsi: '', tampil: false));
      await repo.updateFacility(
        7,
        const CmsFacilityInput(nama: 'Lapangan', deskripsi: '', tampil: false, urutan: 3),
      );

      expect((adapter.sent.first.json! as Map).containsKey('urutan'), isFalse);
      expect(adapter.sent.last.path, '/api/v1/admin/cms/fasilitas/7');
      expect((adapter.sent.last.json! as Map)['urutan'], 3);
      expect((adapter.sent.last.json! as Map)['tampil'], false);
    });

    test('faq: fields, parsing and delete path', () async {
      final (repo, adapter) = await _repo({
        'id': 4,
        'kategori': 'PPDB',
        'pertanyaan': 'Kapan?',
        'jawaban': 'Juni.',
        'urutan': 2,
        'tampil': true,
      }, status: 201);

      final faq = await repo.createFaq(
        const CmsFaqInput(kategori: 'PPDB', pertanyaan: 'Kapan?', jawaban: 'Juni.', tampil: true),
      );
      await repo.deleteFaq(4);

      expect(adapter.sent.first.json, {
        'kategori': 'PPDB',
        'pertanyaan': 'Kapan?',
        'jawaban': 'Juni.',
        'tampil': true,
      });
      expect((faq.id, faq.urutan), (4, 2));
      expect((adapter.sent.last.method, adapter.sent.last.path), ('DELETE', '/api/v1/admin/cms/faq/4'));
    });
  });

  group('unggah media', () {
    test('sends multipart field "file" with the picked filename and returns the relative url', () async {
      final (repo, adapter) = await _repo({'url': '/media/abc123.jpg', 'ukuran': 3}, status: 201);

      final url = await repo.uploadMedia(filename: 'foto saya.png', bytes: Uint8List.fromList([1, 2, 3]));

      final sent = adapter.sent.single;
      expect(url, '/media/abc123.jpg');
      expect((sent.method, sent.path), ('POST', '/api/v1/admin/cms/media'));
      expect(sent.options.contentType, startsWith('multipart/form-data'));
      expect(sent.body, contains('name="file"'));
      expect(sent.body, contains('filename="foto saya.png"'));
    });

    test('a rejected image surfaces the server field message', () async {
      final (repo, _) = await _repo({
        'message': 'Data yang dikirim tidak valid.',
        'errors': {'file': 'Berkas harus berupa gambar JPEG, PNG, atau WebP yang valid.'},
      }, status: 422);

      await expectLater(
        repo.uploadMedia(filename: 'x.gif', bytes: Uint8List.fromList([1])),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiErrorType.validation)
              .having((e) => e.fieldErrors['file'], 'file error', contains('gambar JPEG')),
        ),
      );
    });
  });

  test('validation and conflict errors keep their messages and field errors', () async {
    final (repo, _) = await _repo({
      'message': 'Data yang dikirim tidak valid.',
      'errors': {'gambar_url': 'Gunakan gambar yang diunggah.'},
    }, status: 422);
    await expectLater(
      repo.createFaq(const CmsFaqInput(kategori: 'PPDB', pertanyaan: 'a', jawaban: 'b', tampil: true)),
      throwsA(isA<ApiException>().having((e) => e.fieldErrors, 'fields', {'gambar_url': 'Gunakan gambar yang diunggah.'})),
    );

    final (repo2, _) = await _repo({'message': 'Judul ini sudah dipakai. Coba judul lain.'}, status: 409);
    await expectLater(
      repo2.createPost(
        const CmsPostInput(
          judul: 'x',
          kategori: 'Berita',
          ringkasan: '',
          isi: '',
          status: ContentStatus.draft,
        ),
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.conflict)
            .having((e) => e.message, 'message', 'Judul ini sudah dipakai. Coba judul lain.'),
      ),
    );
  });
}
