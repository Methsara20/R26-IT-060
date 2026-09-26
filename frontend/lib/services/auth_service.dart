import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      try {
        if (kIsWeb) {
          await _googleSignIn.initialize(
            clientId: '171031337876-v1l7ha3nheuim0ijdh2f6paaqfkbdlie.apps.googleusercontent.com',
            serverClientId: '171031337876-v1l7ha3nheuim0ijdh2f6paaqfkbdlie.apps.googleusercontent.com',
          );
        } else {
          await _googleSignIn.initialize(
            serverClientId: '171031337876-v1l7ha3nheuim0ijdh2f6paaqfkbdlie.apps.googleusercontent.com',
          );
        }
      } catch (_) {}
      _initialized = true;
    }
  }

  static Future<String?> signInWithGoogle() async {
    await _ensureInitialized();

    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount account = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication auth = account.authentication;
      
      final String? idToken = auth.idToken;
      
      if (idToken == null || idToken.isEmpty) {
        throw Exception("Google did not return an authentication token. Please try signing in again.");
      }
      
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw Exception("Google Sign-In window was closed. Please select your account again.");
      }
      throw Exception("Google Sign-In failed (${e.code}): ${e.description ?? 'Unknown error'}");
    } catch (e) {
      throw Exception("Google Sign-In failed: $e");
    }
  }

  static Future<void> signOut() async {
    await _ensureInitialized();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}
