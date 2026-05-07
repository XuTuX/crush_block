import 'package:crush_block/constant.dart';
import 'package:crush_block/screens/auth_gate_screen.dart';
import 'package:crush_block/services/auth_service.dart';
import 'package:crush_block/services/database_service.dart';
import 'package:crush_block/services/settings_service.dart';
import 'package:crush_block/services/multiplayer_service.dart';
import 'package:crush_block/theme/app_design_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env", isOptional: true);

  final configError = _validateSupabaseConfig(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  if (configError != null) {
    runApp(MissingConfigApp(message: configError));
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final settingsService = await SettingsService().init();

  runApp(CrushBlockApp(
    settingsService: settingsService,
  ));
}

class AppBinding extends Bindings {
  final SettingsService settingsService;

  AppBinding({
    required this.settingsService,
  });

  @override
  void dependencies() {
    Get.put<SettingsService>(settingsService, permanent: true);
    Get.put(DatabaseService(), permanent: true);
    Get.put(MultiplayerService(), permanent: true);
    Get.put(AuthService(), permanent: true);
  }
}

class MissingConfigApp extends StatelessWidget {
  final String message;

  const MissingConfigApp({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

String? _validateSupabaseConfig({
  required String url,
  required String anonKey,
}) {
  if (url.isEmpty || anonKey.isEmpty) {
    return 'Supabase 설정이 필요합니다.\n.env 파일에 SUPABASE_URL과 SUPABASE_ANON_KEY를 모두 입력해주세요.';
  }

  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    return 'SUPABASE_URL 값이 올바른 URL이 아닙니다.\n예: https://your-project-ref.supabase.co';
  }

  if (uri.scheme != 'https') {
    return 'SUPABASE_URL은 https로 시작해야 합니다.\n예: https://your-project-ref.supabase.co';
  }

  return null;
}

class CrushBlockApp extends StatelessWidget {
  final SettingsService settingsService;

  const CrushBlockApp({
    super.key,
    required this.settingsService,
  });

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Crush Block',
      initialBinding: AppBinding(
        settingsService: settingsService,
      ),
      theme: AppTheme.light,
      navigatorKey: Get.key, // GetX 글로벌 키 설정
      home: const AuthGateScreen(),
    );
  }
}
