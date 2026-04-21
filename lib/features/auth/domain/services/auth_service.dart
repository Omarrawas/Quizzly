import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  String _role = 'user'; 

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get role => _role;
  bool get isAdmin => _role == 'admin' || _role == 'super_admin';

  AuthService() {
    _user = _auth.currentUser;
    if (_user != null) {
      _fetchUserRole(_user!.uid);
    }
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _fetchUserRole(user.uid);
      } else {
        _role = 'user';
        notifyListeners();
      }
    });
    _initializeGoogleSignIn();
  }

  Future<void> _fetchUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _role = doc.data()?['role'] ?? 'user';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching user role: $e');
    }
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize();
    } catch (e) {
      debugPrint('Google Sign In initialization error: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'An error occurred during sign in.');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signUpWithEmail(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'An error occurred during sign up.');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);
    try {
      if (kIsWeb) {
        // Use Firebase's native popup approach for Web to bypass google_sign_in's custom button restrictions
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.addScope('openid');
        
        await _auth.signInWithPopup(googleProvider);
        _setLoading(false);
        return true;
      } else {
        final googleUser = await _googleSignIn.authenticate();
        
        // If authenticate() returns non-nullable, it will throw on error or cancel.
        // We'll wrap it in try-catch in the outer block or here.
        // Given the existing structure, we can just proceed if it didn't throw.

        // authentication is now a getter (info: remove await)
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        // accessToken must be requested via authorizationClient in v7+
        final authorization = await googleUser.authorizationClient.authorizeScopes(
          ['email', 'profile', 'openid'],
        );

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: authorization.accessToken,
          idToken: googleAuth.idToken,
        );

        await _auth.signInWithCredential(credential);
        _setLoading(false);
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'An error occurred during Google sign in.');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}
