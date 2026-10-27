import 'package:aplikasi_guru/core/network/api_exception.dart';
import 'package:aplikasi_guru/features/web_auth/data/web_auth_models.dart';
import 'package:aplikasi_guru/features/website/data/website_models.dart';
import 'package:aplikasi_guru/models/app_models.dart';
import 'package:aplikasi_guru/repositories/web_auth_repository.dart';
import 'package:aplikasi_guru/repositories/website_repository.dart';

class FakeWebsiteRepository implements WebsiteRepository {
  final berita = <Berita>[
    Berita(
      slug: 'libur-semester',
      kategori: BeritaKategori.pengumuman,
      tanggal: DateTime(2026, 10, 5),
      judul: 'Jadwal Libur Semester Ganjil',
      ringkasan: 'Libur dimulai pekan depan.',
    ),
    Berita(
      slug: 'juara-lomba',
      kategori: BeritaKategori.berita,
      tanggal: DateTime(2026, 10, 2),
      judul: 'Siswa Meraih Juara Lomba Cerdas Cermat',
      ringkasan: 'Tim sekolah menang di tingkat kota.',
    ),
    Berita(
      slug: 'jadwal-pelajaran',
      kategori: BeritaKategori.akademik,
      tanggal: DateTime(2026, 9, 28),
      judul: 'Pembaruan Jadwal Pelajaran',
      ringkasan: 'Berlaku mulai Senin.',
    ),
    Berita(
      slug: 'ppdb-2027',
      kategori: BeritaKategori.ppdb,
      tanggal: DateTime(2026, 9, 20),
      judul: 'Pembukaan PPDB Tahun Ajaran 2027/2028',
      ringkasan: 'Pendaftaran dibuka bulan depan.',
    ),
    Berita(
      slug: 'pramuka',
      kategori: BeritaKategori.kegiatan,
      tanggal: DateTime(2026, 9, 15),
      judul: 'Dokumentasi Perkemahan Pramuka',
      ringkasan: 'Foto-foto kegiatan.',
    ),
    Berita(
      slug: 'bazar',
      kategori: BeritaKategori.berita,
      tanggal: DateTime(2026, 9, 8),
      judul: 'Bazar Kreativitas Siswa',
      ringkasan: 'Hasil karya siswa dipamerkan.',
    ),
  ];

  final kegiatan = <Kegiatan>[
    for (var i = 0; i < KegiatanKategori.values.length; i++)
      Kegiatan(
        slug: 'kegiatan-${i + 1}',
        kategori: KegiatanKategori.values[i],
        tanggal: DateTime(2026, 9, 11 + i),
        judul: 'Kegiatan ${KegiatanKategori.values[i].label}',
        deskripsi: 'Deskripsi kegiatan ${i + 1}.',
        fotoUrls: i == 2
            ? const ['https://x.test/1.jpg', 'https://x.test/2.jpg', 'https://x.test/3.jpg']
            : const [],
      ),
  ];

  final fasilitas = const [
    Fasilitas(id: 1, nama: 'Laboratorium Komputer', deskripsi: 'Berisi 20 unit komputer.'),
    Fasilitas(id: 2, nama: 'Perpustakaan'),
  ];

  final faq = const [
    Faq(kategori: FaqKategori.ppdb, pertanyaan: 'Kapan pendaftaran dimulai?', jawaban: 'Bulan Januari.'),
    Faq(kategori: FaqKategori.ppdb, pertanyaan: 'Apa saja persyaratannya?', jawaban: 'Akta kelahiran.'),
    Faq(kategori: FaqKategori.keuangan, pertanyaan: 'Apakah ada SPP?', jawaban: 'Tidak ada.'),
    Faq(kategori: FaqKategori.umum, pertanyaan: 'Jam masuk sekolah?', jawaban: 'Pukul 07.00.'),
    Faq(kategori: FaqKategori.kegiatan, pertanyaan: 'Ada ekstrakurikuler?', jawaban: 'Ada.'),
    Faq(kategori: FaqKategori.umum, pertanyaan: 'Bagaimana menghubungi sekolah?', jawaban: 'Lewat WhatsApp.'),
  ];

  final info = const SchoolInfo(
    npsn: '20500001',
    alamat: 'Jl. Merdeka No. 1, Blitar',
    akreditasi: 'A',
    telepon: '0342-123456',
    email: 'info@sdn02pakunden.sch.id',
    whatsapp: '6281234567890',
  );

  final pages = <String, String>{
    'hero-kicker': 'Kota Blitar',
    'hero-title': 'Sekolah Kami\nUntuk Anak Bangsa',
    'hero-subtitle': 'Subjudul dari admin.',
    'ppdb-banner': 'Banner PPDB dari admin.',
    'kontak-ajakan': 'Ajakan kontak dari admin.',
    'sambutan': 'Selamat datang di SDN 02 Pakunden.',
    'tentang': 'Sekolah dasar negeri di Kota Blitar.',
    'ppdb-informasi': 'PPDB dibuka setiap Januari.',
  };

  ApiException? failNews;
  var newsFetches = 0;

  @override
  Future<List<Berita>> fetchNews() async {
    newsFetches++;
    final error = failNews;
    if (error != null) throw error;
    return berita;
  }

  @override
  Future<Berita> fetchNewsDetail(String slug) async {
    final b = berita.firstWhere((x) => x.slug == slug);
    return Berita(
      slug: b.slug,
      kategori: b.kategori,
      tanggal: b.tanggal,
      judul: b.judul,
      ringkasan: b.ringkasan,
      isi: 'Isi lengkap: ${b.judul}.',
    );
  }

  @override
  Future<List<Kegiatan>> fetchActivities() async => kegiatan;

  @override
  Future<Kegiatan> fetchActivityDetail(String slug) async =>
      kegiatan.firstWhere((k) => k.slug == slug);

  @override
  Future<List<Fasilitas>> fetchFacilities() async => fasilitas;

  @override
  Future<List<Faq>> fetchFaq() async => faq;

  @override
  Future<List<StaffMember>> fetchStaff() async => const [
        StaffMember(nama: 'Bu Rina', jabatan: 'Wali Kelas 5A'),
        StaffMember(nama: 'Pak Andi', jabatan: 'Guru Mapel'),
      ];

  @override
  Future<SchoolInfo> fetchSchoolInfo() async => info;

  @override
  Future<Map<String, String>> fetchPages() async => pages;
}


class FakeWebAuthRepository implements WebAuthRepository {
  static const password = 'Password123';

  static const accounts = {
    'orangtua@contoh.id': (id: 10, name: 'Orang tua Ahmad', role: WebRole.ortu, must: false),
    'ortu.baru@contoh.id': (id: 11, name: 'Orang tua Baru', role: WebRole.ortu, must: true),
    'ortu.lain@contoh.id': (id: 12, name: 'Orang tua Lain', role: WebRole.ortu, must: false),
    'admin@contoh.id': (id: 1, name: 'Admin Sekolah', role: WebRole.admin, must: false),
  };

  final loginAttempts = <String>[];
  final resetRequests = <String>[];
  String? changedPassword;
  var logoutCount = 0;

  @override
  Future<WebAuthResult> login({
    required String email,
    required String password,
    required WebRole role,
  }) async {
    loginAttempts.add(email);
    final account = accounts[email];
    if (account == null || password != FakeWebAuthRepository.password) {
      throw const ApiException(
        type: ApiErrorType.unauthorized,
        message: 'Email atau password tidak sesuai.',
      );
    }
    if (account.role != role) {
      throw const ApiException(
        type: ApiErrorType.forbidden,
        message: 'Akun ini tidak memiliki akses ke halaman ini.',
      );
    }
    return WebAuthResult(
      token: 'token-${account.id}',
      user: AuthUser(
        id: account.id,
        email: email,
        name: account.name,
        mustChangePassword: account.must,
      ),
    );
  }

  @override
  Future<void> changePassword({required String newPassword}) async =>
      changedPassword = newPassword;

  @override
  Future<void> requestPasswordReset(String email) async => resetRequests.add(email);

  @override
  Future<void> logout() async => logoutCount++;
}
