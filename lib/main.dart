import 'package:link_your_area/constant.dart';
import 'package:link_your_area/screens/auth_gate_screen.dart';
import 'package:link_your_area/services/auth_service.dart';
import 'package:link_your_area/services/database_service.dart';
import 'package:link_your_area/services/settings_service.dart';
import 'package:link_your_area/services/multiplayer_service.dart';
import 'package:link_your_area/services/shop_service.dart';
import 'package:link_your_area/theme/app_design_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final settingsService = await SettingsService().init();
  final shopService = await ShopService().init();

  runApp(CrushBlockApp(
    settingsService: settingsService,
    shopService: shopService,
  ));
}

class AppBinding extends Bindings {
  final SettingsService settingsService;
  final ShopService shopService;

  AppBinding({
    required this.settingsService,
    required this.shopService,
  });

  @override
  void dependencies() {
    Get.put<SettingsService>(settingsService, permanent: true);
    Get.put<ShopService>(shopService, permanent: true);
    Get.put(DatabaseService(), permanent: true);
    Get.put(MultiplayerService(), permanent: true);
    Get.put(AuthService(), permanent: true);
  }
}

class CrushBlockApp extends StatelessWidget {
  final SettingsService settingsService;
  final ShopService shopService;

  const CrushBlockApp({
    super.key,
    required this.settingsService,
    required this.shopService,
  });

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Crush Block',
      initialBinding: AppBinding(
        settingsService: settingsService,
        shopService: shopService,
      ),
      theme: AppTheme.light,
      navigatorKey: Get.key, // GetX 글로벌 키 설정
      home: const AuthGateScreen(),
    );
  }
}
