import 'package:equatable/equatable.dart';

class Semester extends Equatable {
  final String id;
  final String name;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Semester({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Semester.fromJson(Map<String, dynamic> json) {
    return Semester(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      isDefault: json['isDefault'] ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, name, isDefault, createdAt, updatedAt];
}