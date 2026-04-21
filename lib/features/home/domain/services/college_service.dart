import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzly/features/home/data/models/college_model.dart';

class CollegeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch all colleges for the "Subject Selection" screen (Trial browse)
  Stream<List<CollegeModel>> getAvailableColleges() {
    return _firestore.collection('colleges').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => CollegeModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  /// Fetch colleges that a specific user has activated
  Stream<List<CollegeModel>> getUserColleges(String userId) {
    // In a real app, you might have a 'user_colleges' collection or a list of IDs in the user document.
    // For now, let's assume we fetch from 'colleges' where 'status' is active or it's specifically linked to the user.
    // Since we don't have a specific linkage yet, let's just fetch all 'colleges' but we could filter by userId if needed.
    return _firestore
        .collection('colleges')
        .where('activated_by', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CollegeModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  /// Add a mock college to Firestore for testing (one-time use)
  Future<void> addSampleColleges() async {
    final colleges = [
      {
        'name': 'دورات مواد الفصل الأول',
        'subtitle': 'السنة التحضيرية للكليات الطبية',
        'iconCode': 0xe54b, // school
        'subjectCount': 5,
        'status': 'demo',
      },
      {
        'name': 'دورات مواد الفصل الثاني',
        'subtitle': 'السنة التحضيرية للكليات الطبية',
        'iconCode': 0xe54b, // school
        'subjectCount': 6,
        'status': 'active',
      }
    ];

    for (var college in colleges) {
      await _firestore.collection('colleges').add(college);
    }
  }
}
