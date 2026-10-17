class ClassModel {
  final String id;
  final String className;
  final String department;
  final String academicYear;
  final bool active;
  final DateTime createdAt;

  ClassModel({
    required this.id,
    required this.className,
    required this.department,
    required this.academicYear,
    required this.active,
    required this.createdAt,
  });

  String get displayName => '$className - $department ($academicYear)';

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] as String,
      className: json['class_name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      academicYear: json['academic_year'] as String? ?? '',
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_name': className,
      'department': department,
      'academic_year': academicYear,
      'active': active,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
