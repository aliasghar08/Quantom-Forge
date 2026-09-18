import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Future<String> getUserId() async {
    final user = _auth.currentUser;
    if (user != null) {
      return user.uid;
    }
    // Fallback if accessed before sign in, though ideally shouldn't happen.
    return '';
  }

  @override
  Future<bool> isAuthenticated() async {
    return _auth.currentUser != null;
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signUp(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<void> signInWithGoogle() async {
    final googleProvider = GoogleAuthProvider();
    await _auth.signInWithPopup(googleProvider);
  }
}
