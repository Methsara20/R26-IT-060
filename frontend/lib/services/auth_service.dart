import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _googleSignIn.initialize(
        serverClientId: '171031337876-v1l7ha3nheuim0ijdh2f6paaqfkbdlie.apps.googleusercontent.com',
      );
      _initialized = true;
    }
  }

  static Future<String?> signInWithGoogle() async {
    try {
      await _ensureInitialized();
      final GoogleSignInAccount account = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication auth = account.authentication;
      
      if (auth.idToken == null) {
        throw Exception("Failed to retrieve ID token from Google");
      }
      
      return auth.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null; // User cancelled
      }
      throw Exception("Google Sign-In failed: $e");
    } catch (e) {
      throw Exception("Google Sign-In failed: $e");
    }
  }

  static Future<void> signOut() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
  }
}
