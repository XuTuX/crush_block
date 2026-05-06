import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:crush_block/screens/auth_gate_screen.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crush_block/config/app_config.dart';
import 'package:crush_block/services/database_service.dart';
import 'package:crush_block/utils/random_nickname_generator.dart';
import 'package:crush_block/services/multiplayer_service.dart';
import 'package:crush_block/services/shop_service.dart';

class AuthService extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;

  var user = Rxn<User>();
  var isLoading = false.obs;
  var isSigningOut = false.obs;
  var isAuthReady = false.obs;
  var loginSuccess = false.obs;
  var userNickname = RxnString();
  var isProfileLoaded = false.obs;
  var hasProfileLoadError = false.obs;
  bool _isRedirectingToAuthGate = false;

  @override
  void onInit() {
    super.onInit();
    user.value = _supabase.auth.currentUser;
    isAuthReady.value = false;
    isProfileLoaded.value = user.value == null;
    hasProfileLoadError.value = false;

    // Listen for auth state changes
    _supabase.auth.onAuthStateChange.listen((data) async {
      user.value = data.session?.user;

      // Handle token refresh events
      if (data.event == AuthChangeEvent.tokenRefreshed) {
        debugPrint('🔵 [AuthService] Token refreshed successfully');
      }

      // If user logs in/out, update nickname accordingly
      if (user.value != null) {
        try {
          await Get.find<ShopService>().loadForCurrentUser();
        } catch (_) {}
        fetchUserProfile();
      } else {
        userNickname.value = null;
        hasProfileLoadError.value = false;
        isProfileLoaded.value = true;
        try {
          await Get.find<ShopService>().loadForCurrentUser();
        } catch (_) {}
      }

      if (data.event == AuthChangeEvent.signedOut) {
        _redirectToAuthGate();
      }
    });

    // Try to recover / refresh session on startup
    _tryRecoverSession();
  }

  /// Fetch the current user's profile including nickname
  Future<void> fetchUserProfile() async {
    isProfileLoaded.value = false;
    hasProfileLoadError.value = false;
    try {
      // Ensure we have a user
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        isProfileLoaded.value = true;
        return;
      }

      final dbService = Get.find<DatabaseService>();

      // Try to fetch profile
      var profile = await dbService.getMyProfile();

      // If profile is not found, it might be a new user and the trigger is still running.
      // Wait a bit and try one more time.
      if (profile == null) {
        debugPrint('🟡 [AuthService] Profile not found, retrying in 500ms...');
        await Future.delayed(const Duration(milliseconds: 500));
        profile = await dbService.getMyProfile();
      }

      if (profile != null) {
        if (profile['nickname'] != null) {
          userNickname.value = profile['nickname'];
          debugPrint(
              '🟢 [AuthService] Nickname fetched: ${userNickname.value}');
        } else {
          // Nickname is null -> Generate and Save automatically
          debugPrint(
              '🟡 [AuthService] Nickname is null, generating new one...');
          await _generateAndSaveRandomNickname();
        }
      } else {
        debugPrint('🟡 [AuthService] Profile still null after retry');
        userNickname.value = null;
      }

      // Mark as loaded only if we successfully checked/processed the profile
      hasProfileLoadError.value = false;
      isProfileLoaded.value = true;
      // Warm up rank summary cache eagerly
      dbService.getMyRankedSummary();
      debugPrint(
          '🔵 [AuthService] Profile load/check finished. Nickname: ${userNickname.value}');
    } catch (e) {
      debugPrint('🔴 [AuthService] Failed to fetch profile: $e');
      hasProfileLoadError.value = true;
      isProfileLoaded.value = true;
    }
  }

  /// Generate a random nickname and save it to DB
  Future<void> _generateAndSaveRandomNickname() async {
    try {
      final dbService = Get.find<DatabaseService>();
      String candidate = '';
      bool available = false;
      int attempts = 0;

      // Try up to 5 times to find a unique nickname
      while (attempts < 5 && !available) {
        candidate = RandomNicknameGenerator.generate();
        available = await dbService.checkNicknameAvailable(candidate);
        attempts++;
      }

      if (available) {
        final error = await updateNickname(candidate);
        if (error == null) {
          debugPrint('🟢 [AuthService] Auto-assigned nickname: $candidate');
        } else {
          debugPrint('🔴 [AuthService] Failed to save auto nickname: $error');
        }
      } else {
        debugPrint(
            '🔴 [AuthService] Failed to generate unique nickname after retries');
      }
    } catch (e) {
      debugPrint('🔴 [AuthService] Error in auto nickname generation: $e');
    }
  }

  /// Update nickname both locally and in DB
  Future<String?> updateNickname(String newNickname) async {
    try {
      final dbService = Get.find<DatabaseService>();
      final error = await dbService.updateNickname(newNickname);
      if (error == null) {
        userNickname.value = newNickname;
      }
      return error;
    } catch (e) {
      return '업데이트 중 오류가 발생했습니다.';
    }
  }

  /// Attempt to recover the session on app launch.
  /// If the token is expired, Supabase SDK will attempt an automatic refresh.
  /// If that fails, sign the user out gracefully.
  Future<void> _tryRecoverSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return;

      // Check if session is expired
      if (session.isExpired) {
        debugPrint('🟡 [AuthService] Session expired, attempting refresh...');
        try {
          await _supabase.auth.refreshSession();
          debugPrint('🟢 [AuthService] Session refreshed successfully');
        } catch (e) {
          debugPrint(
              '🔴 [AuthService] Session refresh failed, signing out: $e');
          await _supabase.auth.signOut();
          user.value = null;
        }
      } else {
        debugPrint('🟢 [AuthService] Valid session found on startup');
      }

      // Fetch profile after session recovery
      if (user.value != null) {
        fetchUserProfile();
      }
    } catch (e) {
      debugPrint('🔴 [AuthService] Session recovery error: $e');
    } finally {
      isAuthReady.value = true;
    }
  }

  /// Returns null on success, or an error message string on failure.
  /// Returns 'cancelled' if user cancelled the operation.
  Future<String?> signInWithGoogle() async {
    try {
      isLoading.value = true;
      debugPrint('🔵 [AuthService] Google Sign In process started');

      final webClientId = AppConfig.googleWebClientId;
      final iosClientId = AppConfig.googleIosClientId;

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: Platform.isIOS ? iosClientId : null,
        serverClientId: webClientId,
      );

      debugPrint('🔵 [AuthService] Requesting Google Sign In...');
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('🟡 [AuthService] User cancelled Google Sign In');
        return 'cancelled';
      }

      debugPrint('🔵 [AuthService] Getting authentication tokens...');
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      debugPrint('🔵 [AuthService] Signing in to Supabase...');
      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      debugPrint('🟢 [AuthService] Google Sign In Success!');
      _triggerLoginSuccess();

      // Fetch profile immediately after login
      await fetchUserProfile();

      return null; // success
    } catch (e) {
      debugPrint('🔴 [AuthService] Google Sign In Failed: $e');
      return '로그인 중 오류가 발생했습니다. 다시 시도해주세요.';
    } finally {
      isLoading.value = false;
      debugPrint(
          '🔵 [AuthService] Login process finished. isLoading set to false.');
    }
  }

  /// Returns null on success, or an error message string on failure.
  /// Returns 'cancelled' if user cancelled the operation.
  Future<String?> signInWithApple() async {
    try {
      isLoading.value = true;
      debugPrint('🔵 [AuthService] Apple Sign In process started');

      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        debugPrint('🔴 [AuthService] Apple Sign In is not available');
        return '이 기기에서는 Apple 로그인을 사용할 수 없어요.';
      }

      // native Apple Sign In
      final rawNonce = _supabase.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      debugPrint('🔵 [AuthService] Requesting Apple ID Credential...');
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw 'Could not find ID Token from Apple.';
      }

      debugPrint('🔵 [AuthService] Signing in to Supabase...');
      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      await _syncAppleProfileMetadata(credential);

      debugPrint('🟢 [AuthService] Apple Sign In Success!');
      _triggerLoginSuccess();

      // Fetch profile immediately after login
      await fetchUserProfile();

      return null; // success
    } on SignInWithAppleAuthorizationException catch (e, st) {
      debugPrint('🔴 [AuthService] Apple authorization failed: $e');
      debugPrintStack(stackTrace: st);
      return _mapAppleAuthorizationError(e);
    } on SignInWithAppleNotSupportedException catch (e, st) {
      debugPrint('🔴 [AuthService] Apple Sign In not supported: $e');
      debugPrintStack(stackTrace: st);
      return '이 기기에서는 Apple 로그인을 사용할 수 없어요.';
    } on AuthException catch (e, st) {
      debugPrint(
          '🔴 [AuthService] Supabase Apple Sign In failed: ${e.message}');
      debugPrintStack(stackTrace: st);
      return 'Apple 로그인 설정에 문제가 있어요. 잠시 후 다시 시도해 주세요.';
    } catch (e, st) {
      debugPrint('🔴 [AuthService] Apple Sign In Failed: $e');
      debugPrintStack(stackTrace: st);
      return '로그인 중 오류가 발생했습니다. 다시 시도해주세요.';
    } finally {
      isLoading.value = false;
      debugPrint(
          '🔵 [AuthService] Login process finished. isLoading set to false.');
    }
  }

  Future<void> _syncAppleProfileMetadata(
    AuthorizationCredentialAppleID credential,
  ) async {
    final givenName = credential.givenName?.trim();
    final familyName = credential.familyName?.trim();
    final fullNameParts = [
      if (familyName != null && familyName.isNotEmpty) familyName,
      if (givenName != null && givenName.isNotEmpty) givenName,
    ];

    final userMetadata = <String, dynamic>{};
    if (givenName != null && givenName.isNotEmpty) {
      userMetadata['given_name'] = givenName;
    }
    if (familyName != null && familyName.isNotEmpty) {
      userMetadata['family_name'] = familyName;
    }
    if (fullNameParts.isNotEmpty) {
      userMetadata['full_name'] = fullNameParts.join(' ');
    }

    if (userMetadata.isEmpty) {
      return;
    }

    try {
      await _supabase.auth.updateUser(
        UserAttributes(data: userMetadata),
      );
      debugPrint('🟢 [AuthService] Saved Apple profile metadata');
    } catch (e, st) {
      debugPrint('🟡 [AuthService] Failed to save Apple profile metadata: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  String _mapAppleAuthorizationError(
    SignInWithAppleAuthorizationException error,
  ) {
    switch (error.code) {
      case AuthorizationErrorCode.canceled:
        return 'cancelled';
      case AuthorizationErrorCode.notInteractive:
        return 'Apple 로그인 화면을 열지 못했어요. 앱을 다시 실행한 뒤 시도해 주세요.';
      case AuthorizationErrorCode.invalidResponse:
        return 'Apple 로그인 응답을 확인하지 못했어요. 다시 시도해 주세요.';
      case AuthorizationErrorCode.notHandled:
      case AuthorizationErrorCode.failed:
      case AuthorizationErrorCode.unknown:
        return 'Apple 로그인에 실패했어요. 잠시 후 다시 시도해 주세요.';
    }
  }

  /// Trigger a brief success animation state
  void _triggerLoginSuccess() {
    loginSuccess.value = true;
    Future.delayed(const Duration(seconds: 1), () {
      loginSuccess.value = false;
    });
  }

  Future<String?> signOut() async {
    if (isSigningOut.value) return null;

    isSigningOut.value = true;
    try {
      // Reset multiplayer state (room subscriptions, cached data)
      try {
        final mpService = Get.find<MultiplayerService>();
        mpService.resetOnLogout();
      } catch (_) {}

      // Best-effort provider sign-out to avoid stale native sessions.
      if (!kIsWeb) {
        try {
          final googleSignIn = GoogleSignIn();
          await googleSignIn.signOut();
        } catch (e) {
          debugPrint('🟡 [AuthService] Google local sign-out skipped: $e');
        }
      }

      await _supabase.auth.signOut();
      user.value = null;
      userNickname.value = null;
      hasProfileLoadError.value = false;
      isProfileLoaded.value = true;

      try {
        await Get.find<ShopService>().loadForCurrentUser();
      } catch (_) {}

      _redirectToAuthGate();

      return null;
    } catch (e) {
      debugPrint('🔴 [AuthService] Sign out failed: $e');
      return '로그아웃 중 오류가 발생했습니다. 다시 시도해주세요.';
    } finally {
      isSigningOut.value = false;
    }
  }

  /// Delete the user's account permanently.
  /// Deletes all user data from the database, then signs out.
  /// Returns null on success, or error message on failure.
  Future<String?> deleteAccount() async {
    try {
      isLoading.value = true;
      debugPrint('🔵 [AuthService] Account deletion started');
      final deletingUserId = _supabase.auth.currentUser?.id;
      if (deletingUserId == null) {
        return '로그인 상태를 확인할 수 없습니다.';
      }

      // Delete the user and all related data server-side in a single owned flow.
      await _supabase.functions.invoke(AppConfig.deleteAccountFunctionName);

      // Reset multiplayer state
      try {
        final mpService = Get.find<MultiplayerService>();
        mpService.resetOnLogout();
      } catch (_) {}

      // Clear local score keys for this user
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('high_score_$deletingUserId');
        await prefs.remove('guest_merged_$deletingUserId');
      } catch (_) {}

      // Sign out from Google / Apple
      try {
        final googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      } catch (_) {}

      // Sign out the Supabase session locally
      try {
        await _supabase.auth.signOut();
      } catch (e) {
        debugPrint('🟡 [AuthService] Local sign-out after deletion failed: $e');
      }
      user.value = null;
      userNickname.value = null;
      hasProfileLoadError.value = false;
      isProfileLoaded.value = true;

      _redirectToAuthGate();

      debugPrint('🟢 [AuthService] Account deletion completed');
      return null;
    } on FunctionException catch (e) {
      debugPrint('🔴 [AuthService] Account delete function failed: $e');
      return '계정 삭제를 완료하지 못했습니다. 잠시 후 다시 시도해주세요.';
    } catch (e) {
      debugPrint('🔴 [AuthService] Account deletion failed: $e');
      return '계정 삭제 중 오류가 발생했습니다. 다시 시도해주세요.';
    } finally {
      isLoading.value = false;
    }
  }

  void _redirectToAuthGate() {
    if (_isRedirectingToAuthGate) return;
    if (Get.key.currentState == null) return;

    _isRedirectingToAuthGate = true;
    Future.microtask(() {
      try {
        Get.offAll(
          () => const AuthGateScreen(),
          transition: Transition.noTransition,
        );
      } finally {
        _isRedirectingToAuthGate = false;
      }
    });
  }
}
