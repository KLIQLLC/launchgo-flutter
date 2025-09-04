import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'models/auth_request.dart';
import 'models/auth_response.dart';

part 'api_service.g.dart';

@RestApi()
abstract class ApiService {
  factory ApiService(Dio dio, {String baseUrl}) = _ApiService;

  // Authentication endpoints
  @POST("/users/auth/google/mobile")
  Future<GoogleAuthResponse> authenticateWithGoogle(@Body() GoogleAuthRequest request);

  // User endpoints
  @GET("/users/me")
  Future<HttpResponse<dynamic>> getUserInfo();

  // Semester endpoints
  @GET("/semesters")
  Future<HttpResponse<dynamic>> getSemesters();

  // Document endpoints
  @GET("/users/{userId}/documents")
  Future<HttpResponse<dynamic>> getDocuments(
    @Path("userId") String userId,
    @Query("semesterId") String semesterId,
  );

  @POST("/users/{userId}/documents")
  Future<HttpResponse<dynamic>> createDocument(
    @Path("userId") String userId,
    @Body() Map<String, dynamic> documentData,
  );

  @PATCH("/users/{userId}/documents/{documentId}")
  Future<HttpResponse<dynamic>> updateDocument(
    @Path("userId") String userId,
    @Path("documentId") String documentId,
    @Body() Map<String, dynamic> documentData,
  );

  @DELETE("/users/{userId}/documents/{documentId}")
  Future<HttpResponse<void>> deleteDocument(
    @Path("userId") String userId,
    @Path("documentId") String documentId,
  );

  // Course endpoints
  @GET("/users/{userId}/courses")
  Future<HttpResponse<dynamic>> getCourses(
    @Path("userId") String userId,
    @Query("semesterId") String semesterId,
  );

  @POST("/users/{userId}/courses")
  Future<HttpResponse<dynamic>> createCourse(
    @Path("userId") String userId,
    @Body() Map<String, dynamic> courseData,
  );

  // Schedule endpoints
  @GET("/users/{userId}/schedule")
  Future<HttpResponse<dynamic>> getSchedule(@Path("userId") String userId);

  // Assignment endpoints
  @GET("/users/{userId}/assignments")
  Future<HttpResponse<dynamic>> getAssignments(@Path("userId") String userId);
}