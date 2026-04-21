import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Universities ---
  Stream<QuerySnapshot> getUniversities() {
    return _db.collection('universities').snapshots();
  }

  Future<void> addUniversity(Map<String, dynamic> data) {
    return _db.collection('universities').add(data);
  }

  Future<void> updateUniversity(String id, Map<String, dynamic> data) {
    return _db.collection('universities').doc(id).update(data);
  }

  Future<void> deleteUniversity(String id) {
    return _db.collection('universities').doc(id).delete();
  }

  // --- Colleges ---
  Stream<QuerySnapshot> getColleges(String universityId) {
    return _db.collection('universities').doc(universityId).collection('colleges').snapshots();
  }

  Future<void> addCollege(String universityId, Map<String, dynamic> data) {
    return _db.collection('universities').doc(universityId).collection('colleges').add(data);
  }

  // --- Semesters ---
  Stream<QuerySnapshot> getSemesters(String uniId, String collegeId) {
    return _db
        .collection('universities')
        .doc(uniId)
        .collection('colleges')
        .doc(collegeId)
        .collection('semesters')
        .snapshots();
  }

  // --- Subjects ---
  Stream<QuerySnapshot> getSubjects(String uniId, String collegeId, String semesterId) {
    return _db
        .collection('universities')
        .doc(uniId)
        .collection('colleges')
        .doc(collegeId)
        .collection('semesters')
        .doc(semesterId)
        .collection('subjects')
        .snapshots();
  }
}
