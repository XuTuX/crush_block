import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends GetxService {
  final RxBool isHapticsOn = true.obs;
  final RxBool isTutorialCompleted = false.obs;
  final RxBool isTutorialDismissedForSession = false.obs;

  static const String _hapticsKey = 'haptics_enabled';
  static const String _tutorialKey = 'tutorial_completed';

  Future<SettingsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    isHapticsOn.value = prefs.getBool(_hapticsKey) ?? true;
    isTutorialCompleted.value = prefs.getBool(_tutorialKey) ?? false;
    return this;
  }

  Future<void> toggleHaptics() async {
    isHapticsOn.value = !isHapticsOn.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsKey, isHapticsOn.value);
  }

  Future<void> completeTutorial() async {
    isTutorialCompleted.value = true;
    isTutorialDismissedForSession.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialKey, true);
  }

  void dismissTutorialForSession() {
    isTutorialDismissedForSession.value = true;
  }

  Future<void> resetTutorial() async {
    isTutorialCompleted.value = false;
    isTutorialDismissedForSession.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialKey, false);
  }
}
