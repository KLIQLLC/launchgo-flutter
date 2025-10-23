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
  final String? getStreamToken;

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
    this.getStreamToken,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? json['studentId'] ?? '',
      name: json['name'] ?? json['firstName'] ?? '',
      email: json['email'],
      status: json['status'],
      gpa: json['gpa'] != null ? double.tryParse(json['gpa'].toString()) : null,
      academicYear: json['academicYear'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : null,
      role: json['role'],
      mentorId: json['mentorId'],
      avatarUrl: json['avatarUrl'] ?? json['avatar'],
      getStreamToken: json['getStreamToken'],
    );
  }

  @override
  List<Object?> get props => [
    id, name, email, status, gpa, academicYear, 
    createdAt, role, mentorId, avatarUrl, getStreamToken
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
  final String? getStreamToken;
  final String? mentorId;
  final String? mentorName;
  final String? mentorAvatar;
  final String? mentorEmail;
  final String? selectedStudentId; // Currently selected student for mentor
  final String? selectedSemesterId; // Currently selected semester
  final double? gpa; // Student's GPA (for student users)
  final String? academicYear; // Student's academic year (for student users)

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
    this.getStreamToken,
    this.mentorId,
    this.mentorName,
    this.mentorAvatar,
    this.mentorEmail,
    this.selectedStudentId,
    this.selectedSemesterId,
    this.gpa,
    this.academicYear,
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
      getStreamToken: userData['getStreamToken'],
      mentorId: userData['mentorId'],
      mentorName: userData['mentorName'],
      mentorAvatar: userData['mentorAvatar'],
      mentorEmail: userData['mentorEmail'],
      selectedSemesterId: null, // Will be set when semesters are loaded
      gpa: userData['gpa'] != null ? double.tryParse(userData['gpa'].toString()) : null,
      academicYear: userData['academicYear'],
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
    String? getStreamToken,
    String? mentorId,
    String? mentorName,
    String? mentorAvatar,
    String? mentorEmail,
    String? selectedStudentId,
    String? selectedSemesterId,
    double? gpa,
    String? academicYear,
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
      getStreamToken: getStreamToken ?? this.getStreamToken,
      mentorId: mentorId ?? this.mentorId,
      mentorName: mentorName ?? this.mentorName,
      mentorAvatar: mentorAvatar ?? this.mentorAvatar,
      mentorEmail: mentorEmail ?? this.mentorEmail,
      selectedStudentId: selectedStudentId ?? this.selectedStudentId,
      selectedSemesterId: selectedSemesterId ?? this.selectedSemesterId,
      gpa: gpa ?? this.gpa,
      academicYear: academicYear ?? this.academicYear,
    );
  }

  bool get isMentor => role == UserRole.mentor;
  bool get isStudent => role == UserRole.student;
  bool get isCaseManager => role == UserRole.caseManager;

  @override
  List<Object?> get props => [id, name, email, role, students, avatarUrl, getStreamToken, mentorId, mentorName, mentorAvatar, mentorEmail, selectedStudentId, gpa, academicYear];
}