import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'models/auth_request.dart';
import 'models/auth_response.dart';

part 'api_service.g.dart';

@RestApi(baseUrl: "https://paqlhj8bef.execute-api.us-west-1.amazonaws.com/api")
abstract class ApiService {
  factory ApiService(Dio dio, {String baseUrl}) = _ApiService;

  @POST("/users/auth/google/mobile")
  Future<GoogleAuthResponse> authenticateWithGoogle(@Body() GoogleAuthRequest request);
}