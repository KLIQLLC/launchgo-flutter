import 'package:equatable/equatable.dart';
import 'semester_model.dart';

enum UserRole {
  student,
  mentor,
  caseManager,
  unknown
}

enum UserStatus {
  active,
  invited,
  pending,
  unknown
}

class Student extends Equatable {
  final String id;
  final String name;
  final String? email;
  final String? status;
  final double? gpa;
  final String? academicYear;
  final DateTime? createdAt;
  final String? role;
  final String? mentorId;
  final String? avatarUrl;

  const Student({
    required this.id,
    required this.name,
    this.email,
    this.status,
    this.gpa,
    this.academicYear,
    this.createdAt,
    this.role,
    this.mentorId,
    this.avatarUrl,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? json['studentId'] ?? '',
      name: json['name'] ?? json['firstName'] ?? '',
      email: json['email'],
      status: json['status'],
      gpa: json['gpa'] != null ? double.tryParse(json['gpa']) : null,
      academicYear: json['academicYear'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : null,
      role: json['role'],
      mentorId: json['mentorId'],
      avatarUrl: json['avatarUrl'] ?? json['avatar'],
    );
  }

  @override
  List<Object?> get props => [
    id, name, email, status, gpa, academicYear, 
    createdAt, role, mentorId, avatarUrl
  ];
}

class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final UserStatus status;
  final DateTime? createdAt;
  final List<Student> students; // For mentors
  final List<Semester> semesters; // Available semesters
  final String? avatarUrl;
  final String? selectedStudentId; // Currently selected student for mentor
  final String? selectedSemesterId; // Currently selected semester

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.createdAt,
    this.students = const [],
    this.semesters = const [],
    this.avatarUrl,
    this.selectedStudentId,
    this.selectedSemesterId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Extract data wrapper if it exists
    final data = json['data'] ?? json;
    final userData = data['user'] ?? data;
    
    // Determine role
    UserRole userRole = UserRole.unknown;
    if (userData['role'] != null) {
      final roleStr = userData['role'].toString().toLowerCase();
      switch (roleStr) {
        case 'student':
          userRole = UserRole.student;
          break;
        case 'mentor':
          userRole = UserRole.mentor;
          break;
        case 'case_manager':
        case 'casemanager':
          userRole = UserRole.caseManager;
          break;
      }
    }
    
    // Determine status
    UserStatus userStatus = UserStatus.unknown;
    if (userData['status'] != null) {
      final statusStr = userData['status'].toString().toUpperCase();
      switch (statusStr) {
        case 'ACTIVE':
          userStatus = UserStatus.active;
          break;
        case 'INVITED':
          userStatus = UserStatus.invited;
          break;
        case 'PENDING':
          userStatus = UserStatus.pending;
          break;
      }
    }

    // Parse students list if available (for mentors)
    List<Student> studentsList = [];
    if (userData['students'] != null && userData['students'] is List) {
      studentsList = (userData['students'] as List)
          .map((student) => Student.fromJson(student))
          .toList();
    }
    
    // Semesters will now be loaded separately from /semesters endpoint
    // Not included in user response anymore

    return UserModel(
      id: userData['id'] ?? userData['userId'] ?? '',
      name: userData['name'] ?? userData['firstName'] ?? '',
      email: userData['email'] ?? '',
      role: userRole,
      status: userStatus,
      createdAt: userData['createdAt'] != null 
          ? DateTime.parse(userData['createdAt'])
          : null,
      students: studentsList,
      semesters: const [], // Semesters loaded separately now
      avatarUrl: userData['avatarUrl'] ?? userData['avatar'],
      selectedSemesterId: null, // Will be set when semesters are loaded
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    UserStatus? status,
    List<Student>? students,
    List<Semester>? semesters,
    String? avatarUrl,
    String? selectedStudentId,
    String? selectedSemesterId,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      students: students ?? this.students,
      semesters: semesters ?? this.semesters,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      selectedStudentId: selectedStudentId ?? this.selectedStudentId,
      selectedSemesterId: selectedSemesterId ?? this.selectedSemesterId,
    );
  }

  bool get isMentor => role == UserRole.mentor;
  bool get isStudent => role == UserRole.student;
  bool get isCaseManager => role == UserRole.caseManager;

  @override
  List<Object?> get props => [id, name, email, role, students, avatarUrl, selectedStudentId];
}