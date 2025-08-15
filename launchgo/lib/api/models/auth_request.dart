import 'package:json_annotation/json_annotation.dart';

part 'auth_request.g.dart';

@JsonSerializable()
class GoogleAuthRequest {
  final String code;

  GoogleAuthRequest({required this.code});

  factory GoogleAuthRequest.fromJson(Map<String, dynamic> json) =>
      _$GoogleAuthRequestFromJson(json);

  Map<String, dynamic> toJson() => _$GoogleAuthRequestToJson(this);
}