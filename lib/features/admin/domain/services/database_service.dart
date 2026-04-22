import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Generic Helpers ---
  Future<void> updateDoc(String path, Map<String, dynamic> data) => 
      _db.doc(path).update(data);
  
  Future<void> deleteDoc(String path) => 
      _db.doc(path).delete();

  // New: Batch order update
  Future<void> updateOrder(List<String> paths) async {
    final batch = _db.batch();
    for (int i = 0; i < paths.length; i++) {
      batch.update(_db.doc(paths[i]), {'order': i});
    }
    await batch.commit();
  }

  // Paths Construction
  String getUniPath(String id) => 'universities/$id';
  String getCollegePath(String uniId, String id) => '${getUniPath(uniId)}/colleges/$id';
  String getDeptPath(String uniId, String collId, String id) => '${getCollegePath(uniId, collId)}/departments/$id';
  String getYearPath(String uniId, String collId, String deptId, String id) => '${getDeptPath(uniId, collId, deptId)}/years/$id';
  String getSemesterPath(String uniId, String collId, String deptId, String yearId, String id) => '${getYearPath(uniId, collId, deptId, yearId)}/semesters/$id';
  String getSubjectPath(String uniId, String collId, String deptId, String yearId, String semId, String id) => '${getSemesterPath(uniId, collId, deptId, yearId, semId)}/subjects/$id';
  String getSectionPath(String uniId, String collId, String deptId, String yearId, String semId, String subId, String id) => '${getSubjectPath(uniId, collId, deptId, yearId, semId, subId)}/sections/$id';

  // --- Streams and Adders (Sorted by 'order') ---
  Stream<QuerySnapshot> getUniversities() => _db.collection('universities').orderBy('order').snapshots();
  Future<DocumentReference> addUniversity(Map<String, dynamic> data) async {
    final count = await _db.collection('universities').count().get();
    return _db.collection('universities').add({...data, 'order': count.count});
  }

  Stream<QuerySnapshot> getColleges(String uniId) => 
      _db.collection('universities').doc(uniId).collection('colleges').orderBy('order').snapshots();
  Future<DocumentReference> addCollege(String uniId, Map<String, dynamic> data) async {
    final count = await _db.collection('universities').doc(uniId).collection('colleges').count().get();
    return _db.collection('universities').doc(uniId).collection('colleges').add({...data, 'order': count.count});
  }

  Stream<QuerySnapshot> getDepartments(String uniId, String collegeId) => 
      _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').orderBy('order').snapshots();
  Future<DocumentReference> addDepartment(String uniId, String collegeId, Map<String, dynamic> data) async {
    final count = await _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').count().get();
    return _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').add({...data, 'order': count.count});
  }

  Stream<QuerySnapshot> getYears(String uniId, String collegeId, String deptId) => 
      _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').orderBy('order').snapshots();
  Future<DocumentReference> addYear(String uniId, String collegeId, String deptId, Map<String, dynamic> data) async {
    final count = await _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').count().get();
    return _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').add({...data, 'order': count.count});
  }

  Stream<QuerySnapshot> getSemesters(String uniId, String collegeId, String deptId, String yearId) => 
      _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').doc(yearId).collection('semesters').orderBy('order').snapshots();
  Future<DocumentReference> addSemester(String uniId, String collegeId, String deptId, String yearId, Map<String, dynamic> data) async {
    final count = await _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').doc(yearId).collection('semesters').count().get();
    return _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').doc(yearId).collection('semesters').add({...data, 'order': count.count});
  }

  Stream<QuerySnapshot> getSubjects(String uniId, String collegeId, String deptId, String yearId, String semesterId) => 
      _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').doc(yearId).collection('semesters').doc(semesterId).collection('subjects').orderBy('order').snapshots();
  Future<DocumentReference> addSubject(String uniId, String collegeId, String deptId, String yearId, String semesterId, Map<String, dynamic> data) async {
    final count = await _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').doc(yearId).collection('semesters').doc(semesterId).collection('subjects').count().get();
    return _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').doc(yearId).collection('semesters').doc(semesterId).collection('subjects').add({...data, 'order': count.count});
  }

  // --- Sections (New Level) ---
  Stream<QuerySnapshot> getSections(String uniId, String collegeId, String deptId, String yearId, String semesterId, String subjectId) => 
      _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').doc(yearId).collection('semesters').doc(semesterId).collection('subjects').doc(subjectId).collection('sections').orderBy('order').snapshots();
  
  Future<DocumentReference> addSection(String uniId, String collegeId, String deptId, String yearId, String semesterId, String subjectId, Map<String, dynamic> data) async {
    final count = await _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').doc(yearId).collection('semesters').doc(semesterId).collection('subjects').doc(subjectId).collection('sections').count().get();
    return _db.collection('universities').doc(uniId).collection('colleges').doc(collegeId).collection('departments').doc(deptId).collection('years').doc(yearId).collection('semesters').doc(semesterId).collection('subjects').doc(subjectId).collection('sections').add({...data, 'order': count.count});
  }

  // --- Questions (Question Bank for a section) ---
  Stream<QuerySnapshot> getQuestions(String sectionPath) => 
      _db.doc(sectionPath).collection('questions').orderBy('order').snapshots();

  Future<DocumentReference> addQuestion(String sectionPath, Map<String, dynamic> data) async {
    final count = await _db.doc(sectionPath).collection('questions').count().get();
    return _db.doc(sectionPath).collection('questions').add({...data, 'order': count.count});
  }
}
