import 'package:crush_block/constant.dart';
import 'package:crush_block/screens/auth_gate_screen.dart';
import 'package:crush_block/services/auth_service.dart';
import 'package:crush_block/services/database_service.dart';
import 'package:crush_block/services/settings_service.dart';
import 'package:crush_block/services/multiplayer_service.dart';
import 'package:crush_block/services/shop_service.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env", isOptional: true);

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const MissingConfigApp());
    return;
  }

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

class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Supabase 설정이 필요합니다.\n.env 파일을 추가하거나 --dart-define으로 SUPABASE_URL과 SUPABASE_ANON_KEY를 전달해주세요.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
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
