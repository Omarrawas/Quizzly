import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:quizzly/main.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

        // ── Record Actual Device Info ──
        await _updateDeviceInfo(uid);

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

  Future<void> _updateDeviceInfo(String uid) async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      Map<String, dynamic> deviceInfoMap = {
        'lastLogin': FieldValue.serverTimestamp(),
      };

      final packageInfo = await PackageInfo.fromPlatform();
      deviceInfoMap['appVersion'] = "${packageInfo.version} (${packageInfo.buildNumber})";

      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        deviceInfoMap['email'] = currentUser.email;
      }

      if (kIsWeb) {
        final webBrowserInfo = await deviceInfo.webBrowserInfo;
        deviceInfoMap['platform'] = 'web';
        deviceInfoMap['deviceName'] = webBrowserInfo.browserName.toString();
        deviceInfoMap['deviceModel'] = 'Web Browser';
        deviceInfoMap['brand'] = 'Web';
        deviceInfoMap['system'] = webBrowserInfo.appVersion ?? 'Unknown';
        deviceInfoMap['uniqueId'] = 'web_session';
        deviceInfoMap['androidId'] = 'web_session';
        deviceInfoMap['fingerprint'] = 'web|browser';
        deviceInfoMap['buildId'] = 'web_build';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceInfoMap['platform'] = 'android';
        deviceInfoMap['deviceName'] = androidInfo.device;
        deviceInfoMap['deviceModel'] = androidInfo.model;
        deviceInfoMap['brand'] = androidInfo.brand;
        deviceInfoMap['system'] = 'Android ${androidInfo.version.release}';
        deviceInfoMap['uniqueId'] = androidInfo.id;
        deviceInfoMap['androidId'] = androidInfo.id;
        deviceInfoMap['fingerprint'] = "${androidInfo.id}|${androidInfo.model}|${androidInfo.brand}|Android";
        deviceInfoMap['buildId'] = androidInfo.display;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceInfoMap['platform'] = 'ios';
        deviceInfoMap['deviceName'] = iosInfo.name;
        deviceInfoMap['deviceModel'] = iosInfo.model;
        deviceInfoMap['brand'] = 'Apple';
        deviceInfoMap['system'] = 'iOS ${iosInfo.systemVersion}';
        deviceInfoMap['uniqueId'] = iosInfo.identifierForVendor ?? 'unknown_ios';
        deviceInfoMap['androidId'] = iosInfo.identifierForVendor ?? 'unknown_ios';
        deviceInfoMap['fingerprint'] = "${iosInfo.identifierForVendor}|${iosInfo.model}|Apple|iOS";
        deviceInfoMap['buildId'] = 'ios_build';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        deviceInfoMap['platform'] = 'windows';
        deviceInfoMap['deviceName'] = windowsInfo.computerName;
        deviceInfoMap['deviceModel'] = 'PC';
        deviceInfoMap['brand'] = 'Windows PC';
        deviceInfoMap['system'] = 'Windows ${windowsInfo.majorVersion}.${windowsInfo.minorVersion}';
        deviceInfoMap['uniqueId'] = 'windows_pc';
        deviceInfoMap['androidId'] = 'windows_pc';
        deviceInfoMap['fingerprint'] = "windows|PC";
        deviceInfoMap['buildId'] = 'windows_build';
      }

      // Backward compatibility fields
      deviceInfoMap['deviceModel'] = deviceInfoMap['deviceModel'];
      deviceInfoMap['deviceOS'] = deviceInfoMap['platform'];
      deviceInfoMap['deviceVersion'] = deviceInfoMap['system'];

      await _firestore.collection('users').doc(uid).set(deviceInfoMap, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
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

  Future<bool> deleteAccount() async {
    _setLoading(true);
    _setError(null);
    try {
      final uid = _user?.uid;
      if (uid == null) {
        _setError('المستخدم غير مسجل الدخول');
        _setLoading(false);
        return false;
      }

      // 1. Delete Firestore User data
      await _firestore.collection('users').doc(uid).delete();
      
      // 2. Delete practice history maps under user_history
      await _firestore.collection('user_history').doc(uid).delete();

      // 3. Delete practice sessions
      final practiceSessions = await _firestore.collection('practice_sessions')
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in practiceSessions.docs) {
        await doc.reference.delete();
      }

      // 4. Delete favorites and other user_lists
      final lists = await _firestore.collection('users')
          .doc(uid)
          .collection('user_lists')
          .get();
      for (var listDoc in lists.docs) {
        final listQuestions = await listDoc.reference.collection('questions').get();
        for (var qDoc in listQuestions.docs) {
          await qDoc.reference.delete();
        }
        await listDoc.reference.delete();
      }

      // 5. Delete mastery
      final mastery = await _firestore.collection('users')
          .doc(uid)
          .collection('mastery')
          .get();
      for (var doc in mastery.docs) {
        await doc.reference.delete();
      }

      // 6. Delete user activated subjects
      final userSubjects = await _firestore.collection('user_subjects')
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in userSubjects.docs) {
        await doc.reference.delete();
      }

      // 7. Delete the user from Firebase Auth
      await _user?.delete();
      
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _setError('يرجى إعادة تسجيل الدخول أولاً لتتمكن من حذف حسابك بشكل آمن.');
      } else {
        _setError(e.message ?? 'حدث خطأ أثناء حذف الحساب.');
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
}
