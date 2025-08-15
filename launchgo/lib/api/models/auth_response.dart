import 'package:json_annotation/json_annotation.dart';

part 'auth_response.g.dart';

@JsonSerializable()
class GoogleAuthResponse {
  final GoogleAuthData? data;

  GoogleAuthResponse({this.data});

  factory GoogleAuthResponse.fromJson(Map<String, dynamic> json) =>
      _$GoogleAuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GoogleAuthResponseToJson(this);
}

@JsonSerializable()
class GoogleAuthData {
  final String accessToken;

  GoogleAuthData({required this.accessToken});

  factory GoogleAuthData.fromJson(Map<String, dynamic> json) =>
      _$GoogleAuthDataFromJson(json);

  Map<String, dynamic> toJson() => _$GoogleAuthDataToJson(this);
}