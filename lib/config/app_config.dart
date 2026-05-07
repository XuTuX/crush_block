// App configuration constants.
// In production, consider using --dart-define or .env files
// to inject these values at build time.
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._(); // prevent instantiation

  // Google OAuth Client IDs
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ??
      const String.fromEnvironment(
        'GOOGLE_WEB_CLIENT_ID',
        defaultValue:
            '205901272812-raopsh8n9namon3vm97u4f0u7s7uco9e.apps.googleusercontent.com',
      );

  static String get googleIosClientId =>
      dotenv.env['GOOGLE_IOS_CLIENT_ID'] ??
      const String.fromEnvironment(
        'GOOGLE_IOS_CLIENT_ID',
        defaultValue:
            '205901272812-hgbcmb7fs0i6spqnbti38v2ji8qvucsn.apps.googleusercontent.com',
      );

  static String get deleteAccountFunctionName =>
      dotenv.env['DELETE_ACCOUNT_FUNCTION'] ??
      const String.fromEnvironment(
        'DELETE_ACCOUNT_FUNCTION',
        defaultValue: 'delete-account',
      );

  static String get gameServerUrl =>
      dotenv.env['GAME_SERVER_URL'] ??
      const String.fromEnvironment(
        'GAME_SERVER_URL',
        defaultValue: 'http://localhost:3001',
      );

  // Legal links
  static const String termsOfServiceUrl = 'https://www.neoreo.org/terms';
  static const String privacyPolicyUrl =
      'https://www.neoreo.org/privacy-policy';
}
