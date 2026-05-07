import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends GetxService {
  final RxBool isHapticsOn = true.obs;

  static const String _hapticsKey = 'haptics_enabled';

  Future<SettingsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    isHapticsOn.value = prefs.getBool(_hapticsKey) ?? true;
    return this;
  }

  Future<void> toggleHaptics() async {
    isHapticsOn.value = !isHapticsOn.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsKey, isHapticsOn.value);
  }
}
