import 'package:image_picker/image_picker.dart';

import '../features/admin/data/cms_models.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class MediaPicker {
  /// Membuka pemilih gambar; null bila pengguna membatalkan.
  Future<PickedImage?> pick();
}

class DeviceMediaPicker implements MediaPicker {
  final _picker = ImagePicker();

  @override
  Future<PickedImage?> pick() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (file == null) return null;
    return PickedImage(name: file.name, bytes: await file.readAsBytes());
  }
}

final mediaPickerProvider = Provider<MediaPicker>((ref) => DeviceMediaPicker());
