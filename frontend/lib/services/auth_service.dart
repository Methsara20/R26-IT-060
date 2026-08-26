import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _googleSignIn.initialize(
        clientId: '171031337876-v1l7ha3nheuim0ijdh2f6paaqfkbdlie.apps.googleusercontent.com',
        serverClientId: '171031337876-v1l7ha3nheuim0ijdh2f6paaqfkbdlie.apps.googleusercontent.com',
      );
      _initialized = true;
    }
  }

  static Future<String?> signInWithGoogle() async {
    try {
      await _ensureInitialized();
      
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount account = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication auth = account.authentication;
      
      if (auth.idToken == null || auth.idToken!.isEmpty) {
        throw Exception("Google did not return an ID token. Please try signing in again.");
      }
      
      return auth.idToken;
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
    await _googleSignIn.signOut();
  }
}
