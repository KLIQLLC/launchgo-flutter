// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleAuthResponse _$GoogleAuthResponseFromJson(Map<String, dynamic> json) =>
    GoogleAuthResponse(
      data: json['data'] == null
          ? null
          : GoogleAuthData.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$GoogleAuthResponseToJson(GoogleAuthResponse instance) =>
    <String, dynamic>{
      'data': instance.data,
    };

GoogleAuthData _$GoogleAuthDataFromJson(Map<String, dynamic> json) =>
    GoogleAuthData(
      accessToken: json['accessToken'] as String,
    );

Map<String, dynamic> _$GoogleAuthDataToJson(GoogleAuthData instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
    };
