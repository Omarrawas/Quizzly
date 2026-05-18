import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Sends a notification to all users
  Future<void> sendGeneralNotification({
    required String title,
    required String body,
    String? imageUrl,
    String? actionUrl,
    String? route,
  }) async {
    await _db.collection('notifications').add({
      'title': title,
      'body': body,
      'target': 'all',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'general',
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      if (actionUrl != null && actionUrl.isNotEmpty) 'actionUrl': actionUrl,
      if (route != null && route.isNotEmpty) 'route': route,
    });
  }

  /// Sends a notification to users of a specific subject
  Future<void> sendSubjectNotification({
    required String title,
    required String body,
    required String subjectId,
    required String subjectName,
    String? imageUrl,
    String? actionUrl,
    String? route,
  }) async {
    await _db.collection('notifications').add({
      'title': title,
      'body': body,
      'target': 'subject',
      'subjectId': subjectId,
      'subjectName': subjectName,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'subject_update',
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      if (actionUrl != null && actionUrl.isNotEmpty) 'actionUrl': actionUrl,
      if (route != null && route.isNotEmpty) 'route': route,
    });
  }

  /// Fetches notifications for a specific user based on their active subjects
  Stream<QuerySnapshot> getNotificationsForUser(List<String> activeSubjectIds) {
    // We can't do a complex "OR" across different fields easily in a single query
    // So we fetch all notifications and filter client-side or use multiple streams
    return _db.collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }
}
