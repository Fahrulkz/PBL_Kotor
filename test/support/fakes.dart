import 'dart:typed_data';

import 'package:aplikasi_guru/core/network/api_exception.dart';
import 'package:aplikasi_guru/features/admin/data/admin_models.dart';
import 'package:aplikasi_guru/features/admin/data/cms_models.dart';
import 'package:aplikasi_guru/features/orang_tua/data/parent_models.dart';
import 'package:aplikasi_guru/models/app_models.dart';
import 'package:aplikasi_guru/repositories/admin_repository.dart';
import 'package:aplikasi_guru/repositories/auth_repository.dart';
import 'package:aplikasi_guru/repositories/guru_repository.dart';
import 'package:aplikasi_guru/repositories/parent_repository.dart';

ApiException apiError(String message, {ApiErrorType type = ApiErrorType.validation}) =>
    ApiException(type: type, message: message);

class FakeAdminRepository implements AdminRepository {
  FakeAdminRepository() {
    guru = [
      const Guru(id: 'g1', name: 'Bu Rina', email: 'bu.rina@contoh.id', role: GuruRole.wali),
      const Guru(id: 'g2', name: 'Pak Andi', email: 'pak.andi@contoh.id', role: GuruRole.mapel),
      const Guru(id: 'g3', name: 'Bu Sari', email: 'bu.sari@contoh.id', role: GuruRole.wali),
    ];
    siswa = [
      for (var i = 1; i <= 12; i++)
        Siswa(
          id: 's$i',
          name: i == 1 ? 'Ahmad Rizky' : i == 2 ? 'Siti Aulia' : 'Siswa Lima $i',
          email: i == 1 ? 'orangtua@contoh.id' : 'ortu.lima$i@contoh.id',
          classCode: '5A',
          parentName: 'Orang tua Wali$i',
        ),
      for (var i = 13; i <= 14; i++)
        Siswa(
          id: 's$i',
          name: 'Siswa B $i',
          email: 'ortu.b$i@contoh.id',
          classCode: '5B',
          parentName: 'Orang tua Wali$i',
        ),
    ];
    admins = [
      const AdminUser(id: 'a1', name: 'Admin Sekolah', email: 'admin@contoh.id'),
      const AdminUser(id: 'a2', name: 'Admin Tata Usaha', email: 'tu@contoh.id'),
    ];
    classes = {
      '5A': const Kelas(code: '5A', waliId: 'g1', mapelIds: ['g2']),
      '5B': const Kelas(code: '5B', waliId: 'g3'),
      '6A': const Kelas(code: '6A'),
    };
    log = [
      LogAktivitas(
        time: DateTime(2026, 10, 8, 8, 12),
        type: LogType.sistem,
        message: 'Sistem dimulai',
      ),
    ];
  }

  late List<Guru> guru;
  late List<Siswa> siswa;
  late List<AdminUser> admins;
  late Map<String, Kelas> classes;
  late List<LogAktivitas> log;
  String year = '2026/2027';
  String late = '';
  String adminPassword = 'Admin12345';
  ApiException? failFetch;
  ApiException? failMutation;
  var _next = 100;

  void _log(LogType type, String message) =>
      log = [LogAktivitas(time: DateTime(2026, 10, 8, 9), type: type, message: message), ...log];

  @override
  Future<AdminUser> fetchMe() async => admins.first;

  @override
  Future<AdminDataset> fetchDataset() async {
    final error = failFetch;
    if (error != null) throw error;
    return AdminDataset(
      guru: guru,
      siswa: siswa,
      admins: admins,
      classes: classes,
      log: log,
      academicYear: year,
      lateLimit: late,
    );
  }

  @override
  Future<void> createClass(String code) async {
    final error = failMutation;
    if (error != null) throw error;
    classes = {...classes, code: Kelas(code: code)};
    _log(LogType.kelas, 'Kelas $code dibuat');
  }

  @override
  Future<void> deleteClass(String code) async {
    classes = {...classes}..remove(code);
    _log(LogType.kelas, 'Kelas $code dihapus');
  }

  @override
  Future<void> setWali(String code, String guruId) async {
    final next = {...classes};
    for (final e in classes.entries) {
      if (e.value.waliId == guruId) next[e.key] = Kelas(code: e.key, mapelIds: e.value.mapelIds);
    }
    next[code] = Kelas(code: code, waliId: guruId, mapelIds: next[code]!.mapelIds);
    classes = next;
  }

  @override
  Future<void> addMapel(String code, String guruId) async {
    final k = classes[code]!;
    classes = {...classes, code: Kelas(code: code, waliId: k.waliId, mapelIds: [...k.mapelIds, guruId])};
  }

  @override
  Future<void> removeMapel(String code, String guruId) async {
    final k = classes[code]!;
    classes = {
      ...classes,
      code: Kelas(
        code: code,
        waliId: k.waliId,
        mapelIds: k.mapelIds.where((i) => i != guruId).toList(),
      ),
    };
  }

  @override
  Future<void> moveStudents(List<String> studentIds, String targetClass) async {
    siswa = [
      for (final s in siswa)
        studentIds.contains(s.id)
            ? Siswa(
                id: s.id,
                name: s.name,
                email: s.email,
                classCode: targetClass,
                parentName: s.parentName,
                active: s.active,
              )
            : s,
    ];
    _log(LogType.siswa, '${studentIds.length} siswa dipindah ke $targetClass');
  }

  Credentials _creds(String email) => (email: email, password: 'Sdn-temp-${_next++}');

  @override
  Future<Credentials> createGuru({
    required String name,
    required String email,
    required GuruRole role,
  }) async {
    guru = [
      ...guru,
      Guru(id: 'g${_next++}', name: name, email: email, role: role, mustChangePassword: true),
    ];
    return _creds(email);
  }

  @override
  Future<Credentials> createAdmin({required String name, required String email}) async {
    admins = [...admins, AdminUser(id: 'a${_next++}', name: name, email: email, mustChangePassword: true)];
    return _creds(email);
  }

  @override
  Future<Credentials> createSiswa({
    required String name,
    required String classCode,
    required String parent,
  }) async {
    final email = 'ortu.${name.toLowerCase().replaceAll(' ', '.')}@contoh.id';
    siswa = [
      ...siswa,
      Siswa(
        id: 's${_next++}',
        name: name,
        email: email,
        classCode: classCode,
        parentName: 'Orang tua $parent',
        mustChangePassword: true,
      ),
    ];
    return _creds(email);
  }

  @override
  Future<void> updateStaffAccount(
    AccountType type,
    String id, {
    required String name,
    required String email,
  }) async {}

  @override
  Future<void> updateSiswa(
    String id, {
    required String name,
    required String classCode,
    required String parent,
  }) async {}

  @override
  Future<Credentials> resetPassword(AccountType type, String id) async =>
      _creds(guru.firstWhere((g) => g.id == id).email);

  @override
  Future<void> setActive(AccountType type, String id, {required bool active}) async {
    guru = [
      for (final g in guru)
        g.id == id
            ? Guru(
                id: g.id,
                name: g.name,
                email: g.email,
                role: g.role,
                active: active,
                mustChangePassword: g.mustChangePassword,
              )
            : g,
    ];
  }

  @override
  Future<void> deleteAccount(AccountType type, String id) async {
    guru = guru.where((g) => g.id != id).toList();
  }

  @override
  Future<void> changeMyPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (oldPassword != adminPassword) throw apiError('Password lama tidak sesuai.');
    adminPassword = newPassword;
  }

  @override
  Future<void> saveSettings({required String academicYear, required String lateLimit}) async {
    year = academicYear;
    late = lateLimit;
  }

  // Kelola Website (CMS)

  var cmsPages = <CmsPage>[
    const CmsPage(kunci: 'hero-title', label: 'Judul utama (Hero)', grup: 'Beranda', baris: 2, isi: 'Judul awal'),
    const CmsPage(kunci: 'sambutan', label: 'Sambutan sekolah', grup: 'Beranda', baris: 6, isi: ''),
    const CmsPage(kunci: 'visi', label: 'Visi', grup: 'Profil Sekolah', baris: 3, isi: 'Visi awal'),
  ];
  var cmsSchool = const CmsSchool(nama: 'SDN 02 Pakunden', kota: 'Blitar', whatsapp: '6281200000000');
  var cmsPosts = <CmsPost>[
    CmsPost(
      slug: 'libur-semester',
      kategori: 'Pengumuman',
      judul: 'Libur Semester',
      ringkasan: 'Ringkas.',
      tanggal: DateTime(2026, 10, 2),
      status: ContentStatus.terbit,
      isi: 'Isi pengumuman libur.',
    ),
    CmsPost(
      slug: 'lomba-puisi',
      kategori: 'Kegiatan',
      judul: 'Lomba Puisi',
      ringkasan: 'Lomba antarkelas.',
      tanggal: DateTime(2026, 9, 20),
      status: ContentStatus.draft,
      isi: 'Isi lomba.',
    ),
  ];
  var cmsActivities = <CmsActivity>[
    CmsActivity(
      slug: 'latihan-pramuka',
      kategori: 'Ekstrakurikuler',
      judul: 'Latihan Pramuka',
      deskripsi: 'Setiap pekan.',
      tanggal: DateTime(2026, 10, 1),
      status: ContentStatus.terbit,
      fotoUrls: const ['/media/a.jpg'],
    ),
  ];
  var cmsFacilities = <CmsFacility>[
    const CmsFacility(id: 1, nama: 'Perpustakaan', deskripsi: 'Buku bacaan.', urutan: 1, tampil: true),
  ];
  var cmsFaqs = <CmsFaq>[
    const CmsFaq(
      id: 1,
      kategori: 'PPDB',
      pertanyaan: 'Kapan PPDB dibuka?',
      jawaban: 'Bulan Juni.',
      urutan: 1,
      tampil: true,
    ),
  ];

  final cmsCalls = <String>[];
  final savedPageBatches = <Map<String, String>>[];
  final uploads = <(String, Uint8List)>[];
  ApiException? cmsError;
  var _cmsId = 100;

  void _cmsFail() {
    final error = cmsError;
    if (error != null) {
      cmsError = null;
      throw error;
    }
  }

  @override
  Future<List<CmsPage>> fetchPages() async => cmsPages;

  @override
  Future<List<CmsPage>> savePages(Map<String, String> changed) async {
    cmsCalls.add('savePages');
    _cmsFail();
    savedPageBatches.add(Map.of(changed));
    cmsPages = [
      for (final p in cmsPages)
        if (changed.containsKey(p.kunci))
          CmsPage(
            kunci: p.kunci,
            label: p.label,
            grup: p.grup,
            baris: p.baris,
            isi: changed[p.kunci]!.trim(),
          )
        else
          p,
    ];
    return cmsPages;
  }

  @override
  Future<CmsSchool> fetchSchool() async => cmsSchool;

  @override
  Future<CmsSchool> saveSchool(CmsSchool school) async {
    cmsCalls.add('saveSchool');
    _cmsFail();
    final digits = school.whatsapp?.replaceAll(RegExp(r'[^0-9]'), '');
    cmsSchool = CmsSchool(
      nama: school.nama,
      kota: school.kota,
      npsn: school.npsn,
      alamat: school.alamat,
      akreditasi: school.akreditasi,
      telepon: school.telepon,
      email: school.email,
      mediaSosial: school.mediaSosial,
      whatsapp: digits == null ? null : (digits.startsWith('0') ? '62${digits.substring(1)}' : digits),
      petaUrl: school.petaUrl,
    );
    return cmsSchool;
  }

  @override
  Future<List<CmsPostSummary>> fetchPosts() async => cmsPosts;

  @override
  Future<CmsPost> fetchPost(String slug) async => cmsPosts.firstWhere((p) => p.slug == slug);

  CmsPost _post(String slug, CmsPostInput i) => CmsPost(
        slug: slug,
        kategori: i.kategori,
        judul: i.judul,
        ringkasan: i.ringkasan,
        tanggal: i.tanggal ?? DateTime(2026, 10, 8),
        status: i.status,
        gambarUrl: i.gambarUrl,
        isi: i.isi,
      );

  final postInputs = <CmsPostInput>[];

  @override
  Future<CmsPost> createPost(CmsPostInput input) async {
    cmsCalls.add('createPost');
    _cmsFail();
    postInputs.add(input);
    final post = _post('post-${_cmsId++}', input);
    cmsPosts = [post, ...cmsPosts];
    return post;
  }

  @override
  Future<CmsPost> updatePost(String slug, CmsPostInput input) async {
    cmsCalls.add('updatePost:$slug');
    _cmsFail();
    postInputs.add(input);
    final post = _post(slug, input);
    cmsPosts = [for (final p in cmsPosts) p.slug == slug ? post : p];
    return post;
  }

  @override
  Future<void> deletePost(String slug) async {
    cmsCalls.add('deletePost:$slug');
    cmsPosts = [for (final p in cmsPosts) if (p.slug != slug) p];
  }

  @override
  Future<List<CmsActivity>> fetchActivities() async => cmsActivities;

  CmsActivity _activity(String slug, CmsActivityInput i) => CmsActivity(
        slug: slug,
        kategori: i.kategori,
        judul: i.judul,
        deskripsi: i.deskripsi,
        tanggal: i.tanggal ?? DateTime(2026, 10, 8),
        status: i.status,
        fotoUrls: i.fotoUrls,
      );

  @override
  Future<CmsActivity> createActivity(CmsActivityInput input) async {
    cmsCalls.add('createActivity');
    _cmsFail();
    final item = _activity('kegiatan-${_cmsId++}', input);
    cmsActivities = [item, ...cmsActivities];
    return item;
  }

  @override
  Future<CmsActivity> updateActivity(String slug, CmsActivityInput input) async {
    cmsCalls.add('updateActivity:$slug');
    _cmsFail();
    final item = _activity(slug, input);
    cmsActivities = [for (final a in cmsActivities) a.slug == slug ? item : a];
    return item;
  }

  @override
  Future<void> deleteActivity(String slug) async {
    cmsCalls.add('deleteActivity:$slug');
    cmsActivities = [for (final a in cmsActivities) if (a.slug != slug) a];
  }

  @override
  Future<List<CmsFacility>> fetchFacilities() async => cmsFacilities;

  CmsFacility _facility(int id, CmsFacilityInput i) => CmsFacility(
        id: id,
        nama: i.nama,
        deskripsi: i.deskripsi,
        urutan: i.urutan ?? cmsFacilities.length + 1,
        tampil: i.tampil,
        gambarUrl: i.gambarUrl,
      );

  @override
  Future<CmsFacility> createFacility(CmsFacilityInput input) async {
    cmsCalls.add('createFacility');
    _cmsFail();
    final item = _facility(_cmsId++, input);
    cmsFacilities = [...cmsFacilities, item];
    return item;
  }

  @override
  Future<CmsFacility> updateFacility(int id, CmsFacilityInput input) async {
    cmsCalls.add('updateFacility:$id');
    _cmsFail();
    final item = _facility(id, input);
    cmsFacilities = [for (final f in cmsFacilities) f.id == id ? item : f];
    return item;
  }

  @override
  Future<void> deleteFacility(int id) async {
    cmsCalls.add('deleteFacility:$id');
    cmsFacilities = [for (final f in cmsFacilities) if (f.id != id) f];
  }

  @override
  Future<List<CmsFaq>> fetchFaqs() async => cmsFaqs;

  CmsFaq _faq(int id, CmsFaqInput i) => CmsFaq(
        id: id,
        kategori: i.kategori,
        pertanyaan: i.pertanyaan,
        jawaban: i.jawaban,
        urutan: i.urutan ?? cmsFaqs.length + 1,
        tampil: i.tampil,
      );

  @override
  Future<CmsFaq> createFaq(CmsFaqInput input) async {
    cmsCalls.add('createFaq');
    _cmsFail();
    final item = _faq(_cmsId++, input);
    cmsFaqs = [...cmsFaqs, item];
    return item;
  }

  @override
  Future<CmsFaq> updateFaq(int id, CmsFaqInput input) async {
    cmsCalls.add('updateFaq:$id');
    _cmsFail();
    final item = _faq(id, input);
    cmsFaqs = [for (final f in cmsFaqs) f.id == id ? item : f];
    return item;
  }

  @override
  Future<void> deleteFaq(int id) async {
    cmsCalls.add('deleteFaq:$id');
    cmsFaqs = [for (final f in cmsFaqs) if (f.id != id) f];
  }

  @override
  Future<String> uploadMedia({required String filename, required Uint8List bytes}) async {
    cmsCalls.add('uploadMedia');
    _cmsFail();
    uploads.add((filename, bytes));
    return '/media/upload-${uploads.length}.jpg';
  }
}

class FakeParentRepository implements ParentRepository {
  FakeParentRepository() {
    final days = <HariKehadiran>[];
    const marks = {
      9: {9: AttendanceStatus.terlambat, 15: AttendanceStatus.izin, 23: AttendanceStatus.sakit},
      10: {5: AttendanceStatus.terlambat, 7: AttendanceStatus.terlambat},
    };
    for (final (month, last) in [(9, 30), (10, 8)]) {
      for (var d = 1; d <= last; d++) {
        final date = DateTime(2026, month, d);
        if (date.weekday <= DateTime.friday) {
          days.add(HariKehadiran(
            tanggal: date,
            status: marks[month]![d] ?? AttendanceStatus.hadir,
          ));
        }
      }
    }
    attendance = days;
  }

  final List<Anak> children = [
    Anak(
      id: 1,
      nama: 'Ahmad Rizky',
      kelas: '5A',
      klasifikasi: Classification.cukup,
      literasi: 82,
      numerasi: 76,
      persenKehadiran: 96,
      jumlahTerlambat: 2,
      trenLiterasi: const [76, 78, 80, 81, 82],
      trenNumerasi: const [74, 73, 75, 76, 76],
      trenKehadiran: const [100, 95, 96, 96],
      riwayatKlasifikasi: const [
        RiwayatKlasifikasi(bulan: 'Agustus', klasifikasi: Classification.cukup),
        RiwayatKlasifikasi(bulan: 'Oktober', klasifikasi: Classification.cukup),
      ],
      nis: '12345',
      waliKelas: 'Bu Rina',
      tahunAjaran: '2026/2027',
      diperbarui: DateTime(2026, 10, 8),
      nilai: [
        NilaiUjian(
          id: 1,
          kategori: SubjectCategory.literasi,
          jenis: 'Ulangan Harian 3',
          nilai: 85,
          sebelumnya: 82,
          tanggal: DateTime(2026, 10, 6),
          catatan: 'Peningkatan yang baik.',
        ),
        NilaiUjian(
          id: 2,
          kategori: SubjectCategory.numerasi,
          jenis: 'Tugas 2',
          nilai: 76,
          sebelumnya: 75,
          tanggal: DateTime(2026, 10, 5),
          catatan: 'Stabil.',
        ),
      ],
    ),
    const Anak(
      id: 2,
      nama: 'Aisyah Rizky',
      kelas: '2A',
      klasifikasi: Classification.mahir,
      literasi: 90,
      numerasi: 88,
      persenKehadiran: 98,
      jumlahTerlambat: 0,
      trenLiterasi: [86, 87, 89, 90, 90],
      trenNumerasi: [84, 86, 87, 88, 88],
      trenKehadiran: [100, 100, 96, 98],
      riwayatKlasifikasi: [],
      nilai: [],
    ),
  ];

  late final List<HariKehadiran> attendance;
  List<ParentNotification> notifications = const [
    ParentNotification(id: 11, title: 'Nilai Literasi baru ditambahkan.', gradeId: 1),
    ParentNotification(id: 12, title: 'Kehadiran hari ini tercatat: Hadir.', tab: 2),
  ];
  final markedRead = <int>[];
  ApiException? failChildren;
  var childrenFetches = 0;

  @override
  Future<List<Anak>> fetchChildren() async {
    childrenFetches++;
    final error = failChildren;
    if (error != null) throw error;
    return children;
  }

  @override
  Future<List<HariKehadiran>> fetchAttendance(int childId) async =>
      childId == 1 ? attendance : const [];

  @override
  Future<List<HistoryItem>> fetchHistory(int childId) async => childId == 1
      ? [
          HistoryItem(
            kind: HistoryKind.nilai,
            date: DateTime(2026, 10, 6),
            title: 'Literasi 85',
            description: 'Peningkatan yang baik.',
          ),
          HistoryItem(
            kind: HistoryKind.klasifikasi,
            date: DateTime(2026, 10, 1),
            title: 'Cukup',
            description: 'Tidak berubah dari bulan lalu.',
          ),
        ]
      : const [];

  @override
  Future<List<ParentNotification>> fetchNotifications() async => notifications;

  @override
  Future<void> markNotificationRead(int id) async => markedRead.add(id);

  @override
  Future<void> markAllNotificationsRead() async =>
      markedRead.addAll(notifications.map((n) => n.id));
}

class FakeAuthRepository implements AuthRepository {
  static const accounts = {
    'pak.andi@contoh.id': (
      name: 'Pak Andi',
      nip: '198501012010011001',
      wali: <String>[],
      mapel: ['5A', '5B'],
      must: false,
    ),
    'bu.rina@contoh.id': (
      name: 'Bu Rina',
      nip: null,
      wali: ['5A'],
      mapel: <String>[],
      must: false,
    ),
    'guru.baru@contoh.id': (
      name: 'Guru Baru',
      nip: null,
      wali: <String>[],
      mapel: ['5A'],
      must: true,
    ),
  };

  String? lateLimit = '07:15';
  String? changedPassword;
  var loggedOut = false;

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    final a = accounts[email];
    if (a == null || password != 'Guru12345') {
      throw apiError('Email atau password tidak sesuai.', type: ApiErrorType.unauthorized);
    }
    return AuthSession(
      token: 't',
      user: AuthUser(
        id: 1,
        email: email,
        name: a.name,
        mustChangePassword: a.must,
        nip: a.nip,
      ),
      waliClasses: a.wali,
      mapelClasses: a.mapel,
      lateLimit: lateLimit,
    );
  }

  @override
  Future<AuthSession?> restore() async => null;

  @override
  Future<void> changePassword({required String newPassword}) async => changedPassword = newPassword;

  @override
  Future<void> logout() async => loggedOut = true;
}

class FakeGuruRepository implements GuruRepository {
  final Map<String, ClassData> classes = {
    '5A': ClassData(
      students: const [
        Student(
          id: 1,
          name: 'Ahmad Rizky',
          classification: Classification.cukup,
          status: AttendanceStatus.hadir,
          time: '07:18',
          literasi: 82,
          numerasi: 76,
        ),
        Student(
          id: 2,
          name: 'Siti Aulia',
          classification: Classification.mahir,
          status: AttendanceStatus.terlambat,
          time: '07:22',
          literasi: 93,
          numerasi: 90,
        ),
        Student(
          id: 3,
          name: 'Dimas Arya',
          classification: Classification.perlu,
          status: AttendanceStatus.alpa,
          literasi: 58,
          numerasi: 52,
          declining: true,
        ),
      ],
      grades: [
        GradeEntry(
          id: 1,
          studentId: 1,
          studentName: 'Ahmad Rizky',
          category: SubjectCategory.literasi,
          assessment: 'Ulangan Harian',
          value: 85,
          previous: 82,
          date: DateTime(2026, 10, 6),
          note: 'Meningkat.',
        ),
      ],
      averageLiterasi: 78,
      averageNumerasi: 74,
      literasiTrend: const [74, 75, 77, 78],
      numerasiTrend: const [70, 71, 73, 74],
      attendanceTrend: const [93, 91, 94, 92],
    ),
    '5B': ClassData.empty,
  };

  final attendanceCalls = <(int, AttendanceStatus, String)>[];
  final createdGrades = <GradeInput>[];
  final faceScans = <(String, Uint8List)>[];
  FaceScanResult faceResult = const FaceNotRecognized();
  Object? faceError;

  @override
  Future<List<ClassInfo>> fetchClassSummaries() async => [
        const ClassInfo(code: '5A', studentCount: 3, attendancePercent: 67),
        const ClassInfo(code: '5B', studentCount: 0, attendancePercent: 0),
      ];

  @override
  Future<ClassData> fetchClassData(String classCode) async =>
      classes[classCode] ?? ClassData.empty;

  @override
  Future<void> setAttendance({
    required String classCode,
    required int studentId,
    required AttendanceStatus status,
    String note = '',
  }) async {
    attendanceCalls.add((studentId, status, note));
    final data = classes[classCode]!;
    classes[classCode] = ClassData(
      students: [
        for (final s in data.students)
          s.id == studentId ? s.copyWith(status: status, time: status.isPresent ? '07:50' : '') : s,
      ],
      grades: data.grades,
      averageLiterasi: data.averageLiterasi,
      averageNumerasi: data.averageNumerasi,
      literasiTrend: data.literasiTrend,
      numerasiTrend: data.numerasiTrend,
      attendanceTrend: data.attendanceTrend,
    );
  }

  @override
  Future<FaceScanResult> recognizeFace({
    required String classCode,
    required Uint8List image,
  }) async {
    faceScans.add((classCode, image));
    final error = faceError;
    if (error != null) throw error;
    return faceResult;
  }

  @override
  Future<void> finishAttendance(String classCode) async {}

  @override
  Future<void> createGrade(String classCode, GradeInput input) async => createdGrades.add(input);

  @override
  Future<void> updateGrade(int gradeId, GradeInput input) async {}

  @override
  Future<void> deleteGrade(int gradeId) async {}

  @override
  Future<List<AppNotification>> fetchNotifications() async => const [];

  @override
  Future<void> markNotificationRead(int id) async {}

  @override
  Future<void> markAllNotificationsRead() async {}

  @override
  Future<List<ActivityItem>> fetchActivities() async => const [];
}
