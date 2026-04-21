import 'package:flutter/material.dart';

/// نموذج بيانات الفئة/الكلية
class CollegeModel {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final int subjectCount;
  final SubscriptionStatus status;

  const CollegeModel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.subjectCount,
    required this.status,
  });

  factory CollegeModel.fromMap(Map<String, dynamic> map, String docId) {
    return CollegeModel(
      id: docId,
      name: map['name'] ?? '',
      subtitle: map['subtitle'] ?? '',
      icon: IconData(map['iconCode'] ?? Icons.school_rounded.codePoint, fontFamily: 'MaterialIcons'),
      subjectCount: map['subjectCount'] ?? 0,
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'demo'),
        orElse: () => SubscriptionStatus.demo,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'subtitle': subtitle,
      'iconCode': icon.codePoint,
      'subjectCount': subjectCount,
      'status': status.name,
    };
  }
}

enum SubscriptionStatus { demo, active, locked }
