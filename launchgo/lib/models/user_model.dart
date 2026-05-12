import 'package:equatable/equatable.dart';
import 'semester_model.dart';
import 'user_permission_type.dart';

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

/// Assigned mentor (API field `mentors` on student profile / student records).
class Mentor extends Equatable {
  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;

  const Mentor({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
  });

  factory Mentor.fromJson(Map<String, dynamic> json) {
    return Mentor(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ??
          json['firstName']?.toString() ??
          '',
      email: json['email']?.toString(),
      avatarUrl: json['avatarUrl']?.toString() ??
          json['avatar']?.toString() ??
          json['image']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, name, email, avatarUrl];
}

List<Mentor> _mentorsFromJson(dynamic raw) {
  if (raw is! List) return [];
  return raw
      .map((e) {
        if (e is Map<String, dynamic>) {
          return Mentor.fromJson(e);
        }
        if (e is Map) {
          return Mentor.fromJson(Map<String, dynamic>.from(e));
        }
        return null;
      })
      .whereType<Mentor>()
      .where((m) => m.id.isNotEmpty)
      .toList();
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
  /// Co-mentors for this student (when returned on student objects).
  final List<Mentor> mentors;
  final String? avatarUrl;
  final String? chatGetStreamToken;
  final String? callGetStreamToken;

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
    this.mentors = const [],
    this.avatarUrl,
    this.chatGetStreamToken,
    this.callGetStreamToken,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    var mentorsList = _mentorsFromJson(json['mentors']);
    if (mentorsList.isEmpty && json['mentorId'] != null) {
      final mid = json['mentorId'].toString();
      if (mid.isNotEmpty) {
        mentorsList = [
          Mentor(
            id: mid,
            name: json['mentorName']?.toString() ?? 'Mentor',
            email: json['mentorEmail']?.toString(),
            avatarUrl: json['mentorAvatar']?.toString(),
          ),
        ];
      }
    }
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
      mentors: mentorsList,
      avatarUrl: json['avatarUrl'] ?? json['avatar'],
      chatGetStreamToken: json['chatGetStreamToken'],
      callGetStreamToken: json['callGetStreamToken'],
    );
  }

  @override
  List<Object?> get props => [
    id, name, email, status, gpa, academicYear,
    createdAt, role, mentorId, mentors, avatarUrl, chatGetStreamToken, callGetStreamToken
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
  final String? chatGetStreamToken;
  final String? callGetStreamToken;
  final String? mentorId;
  final String? mentorName;
  final String? mentorAvatar;
  final String? mentorEmail;
  /// All mentors assigned to this student (API `mentors`). Legacy `mentorId` kept for compatibility.
  final List<Mentor> mentors;
  final String? selectedStudentId; // Currently selected student for mentor
  final String? selectedSemesterId; // Currently selected semester
  final double? gpa; // Student's GPA (for student users)
  final String? academicYear; // Student's academic year (for student users)
  /// Server-driven feature flags (students; keys match [UserPermissionType.apiKey]).
  final Map<String, bool> permissions;

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
    this.chatGetStreamToken,
    this.callGetStreamToken,
    this.mentorId,
    this.mentorName,
    this.mentorAvatar,
    this.mentorEmail,
    this.mentors = const [],
    this.selectedStudentId,
    this.selectedSemesterId,
    this.gpa,
    this.academicYear,
    this.permissions = const {},
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

    var mentorsList = _mentorsFromJson(userData['mentors']);
    if (mentorsList.isEmpty && userData['mentorId'] != null) {
      final mid = userData['mentorId'].toString();
      if (mid.isNotEmpty) {
        mentorsList = [
          Mentor(
            id: mid,
            name: userData['mentorName']?.toString() ?? 'Mentor',
            email: userData['mentorEmail']?.toString(),
            avatarUrl: userData['mentorAvatar']?.toString(),
          ),
        ];
      }
    }

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
      chatGetStreamToken: userData['chatGetStreamToken'],
      callGetStreamToken: userData['callGetStreamToken'],
      mentorId: userData['mentorId'],
      mentorName: userData['mentorName'],
      mentorAvatar: userData['mentorAvatar'],
      mentorEmail: userData['mentorEmail'],
      mentors: mentorsList,
      selectedSemesterId: null, // Will be set when semesters are loaded
      gpa: userData['gpa'] != null ? double.tryParse(userData['gpa'].toString()) : null,
      academicYear: userData['academicYear'],
      permissions: parseUserPermissions(userData['permissions']),
    );
  }

  /// Distinct mentor user IDs for Stream channel membership (student channel).
  List<String> get mentorIdsForChatChannel {
    final ids = <String>{};
    for (final m in mentors) {
      if (m.id.isNotEmpty) ids.add(m.id);
    }
    final legacy = mentorId;
    if (legacy != null && legacy.isNotEmpty) ids.add(legacy);
    return ids.toList();
  }

  /// Title for chat UI when the current user is a student.
  String get studentChatDisplayTitle {
    if (mentors.isEmpty) return mentorName ?? 'Chat';
    if (mentors.length == 1) return mentors.first.name;
    return mentors.map((m) => m.name).join(', ');
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
    String? chatGetStreamToken,
    String? callGetStreamToken,
    String? mentorId,
    String? mentorName,
    String? mentorAvatar,
    String? mentorEmail,
    List<Mentor>? mentors,
    String? selectedStudentId,
    String? selectedSemesterId,
    double? gpa,
    String? academicYear,
    Map<String, bool>? permissions,
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
      chatGetStreamToken: chatGetStreamToken ?? this.chatGetStreamToken,
      callGetStreamToken: callGetStreamToken ?? this.callGetStreamToken,
      mentorId: mentorId ?? this.mentorId,
      mentorName: mentorName ?? this.mentorName,
      mentorAvatar: mentorAvatar ?? this.mentorAvatar,
      mentorEmail: mentorEmail ?? this.mentorEmail,
      mentors: mentors ?? this.mentors,
      selectedStudentId: selectedStudentId ?? this.selectedStudentId,
      selectedSemesterId: selectedSemesterId ?? this.selectedSemesterId,
      gpa: gpa ?? this.gpa,
      academicYear: academicYear ?? this.academicYear,
      permissions: permissions ?? this.permissions,
    );
  }

  bool hasPermission(UserPermissionType type) =>
      permissionMapValue(permissions, type);

  bool get isMentor => role == UserRole.mentor;
  bool get isStudent => role == UserRole.student;
  bool get isCaseManager => role == UserRole.caseManager;

  @override
  List<Object?> get props => [id, name, email, role, students, avatarUrl, chatGetStreamToken, callGetStreamToken, mentorId, mentorName, mentorAvatar, mentorEmail, mentors, selectedStudentId, gpa, academicYear, permissions];
}