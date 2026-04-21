import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Generic helper for subcollections to avoid repetition
  Stream<QuerySnapshot> getSubcollectionStream(String path) {
    return _db.collection(path).snapshots();
  }

  // --- Universities ---
  Stream<QuerySnapshot> getUniversities() => _db.collection('universities').snapshots();
  Future<DocumentReference> addUniversity(Map<String, dynamic> data) => _db.collection('universities').add(data);
  Future<void> deleteUniversity(String id) => _db.collection('universities').doc(id).delete();
  Future<void> updateUniversity(String id, Map<String, dynamic> data) => _db.collection('universities').doc(id).update(data);

  // --- Colleges ---
  Stream<QuerySnapshot> getColleges(String uniId) => 
      _db.collection('universities').doc(uniId).collection('colleges').snapshots();
  Future<DocumentReference> addCollege(String uniId, Map<String, dynamic> data) => 
      _db.collection('universities').doc(uniId).collection('colleges').add(data);

  // --- Departments ---
  Stream<QuerySnapshot> getDepartments(String uniId, String collegeId) => 
      _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').snapshots();
  Future<DocumentReference> addDepartment(String uniId, String collegeId, Map<String, dynamic> data) => 
      _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').add(data);

  // --- Years ---
  Stream<QuerySnapshot> getYears(String uniId, String collegeId, String deptId) => 
      _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').snapshots();
  Future<DocumentReference> addYear(String uniId, String collegeId, String deptId, Map<String, dynamic> data) => 
      _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').add(data);

  // --- Semesters ---
  Stream<QuerySnapshot> getSemesters(String uniId, String collegeId, String deptId, String yearId) => 
      _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').doc(yearId).collection('semesters').snapshots();
  Future<DocumentReference> addSemester(String uniId, String collegeId, String deptId, String yearId, Map<String, dynamic> data) => 
      _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').doc(yearId).collection('semesters').add(data);

  // --- Subjects ---
  Stream<QuerySnapshot> getSubjects(String uniId, String collegeId, String deptId, String yearId, String semesterId) => 
      _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').doc(yearId).collection('semesters').doc(semesterId).collection('subjects').snapshots();
  Future<DocumentReference> addSubject(String uniId, String collegeId, String deptId, String yearId, String semesterId, Map<String, dynamic> data) => 
      _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').doc(yearId).collection('semesters').doc(semesterId).collection('subjects').add(data);
}
