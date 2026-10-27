import '../../../core/network/api_exception.dart';
import '../../../widgets/app_overlays.dart';

Future<T?> guardAdmin<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on ApiException catch (e) {
    AppToast.show(e.message);
    return null;
  }
}
