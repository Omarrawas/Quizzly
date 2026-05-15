import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:quizzly/main.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        await _firestore.collection('users').doc(uid).set({
          'email': currentUser.email,
        }, SetOptions(merge: true));
      }

      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _role = doc.data()?['role'] ?? 'user';
        
        // ── Device Binding Check for Students ──
        if (!isAdmin) {
          final isBound = await _verifyDeviceBinding(uid, doc.data()?['deviceId']);
          if (!isBound) return; // Halt if not bound to this device
        }

        notifyListeners();
        _applyScreenProtection();
      }
    } catch (e) {
      debugPrint('Error fetching user role: $e');
    }
  }

  Future<String> _getDeviceID() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_installation_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_installation_id', deviceId);
    }
    return deviceId;
  }

  Future<bool> _verifyDeviceBinding(String uid, String? registeredDeviceId) async {
    final currentDeviceId = await _getDeviceID();

    if (registeredDeviceId == null || registeredDeviceId.isEmpty) {
      // First time -> bind to this device
      await _firestore.collection('users').doc(uid).set({
        'deviceId': currentDeviceId,
      }, SetOptions(merge: true));
      return true;
    } else if (registeredDeviceId != currentDeviceId) {
      // Bound to another device!
      await signOut();
      _setError('هذا الحساب مرتبط بجهاز آخر. لا يمكن استخدام التطبيق من جهازين في نفس الوقت. يرجى التواصل مع الإدارة لإلغاء الجلسة السابقة.');
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('هذا الحساب مرتبط بجهاز آخر. تواصل مع الإدارة لإلغاء الارتباط.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return false; 
    }

    return true; // Match
  }

  Future<void> _applyScreenProtection() async {
    if (kIsWeb) return;
    try {
      if (isAdmin) {
        await ScreenProtector.preventScreenshotOff();
      } else {
        await ScreenProtector.preventScreenshotOn();
        await ScreenProtector.protectDataLeakageWithBlur(); // Protects app switch view
      }
    } catch (e) {
      debugPrint('ScreenProtector error: $e');
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
    if (!kIsWeb) {
      try {
        await ScreenProtector.preventScreenshotOff(); // Turn off when logged out
      } catch (_) {}
    }
  }
}
