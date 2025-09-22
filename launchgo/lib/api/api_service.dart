import 'dart:io';
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
  
  @PATCH("/students/{studentId}")
  Future<HttpResponse<dynamic>> updateStudentInfo(
    @Path("studentId") String studentId,
    @Body() Map<String, dynamic> studentData,
  );

  // Semester endpoints
  @GET("/semesters")
  Future<HttpResponse<dynamic>> getSemesters();

  // Deadlines endpoints
  @GET("/users/{userId}/deadlines")
  Future<HttpResponse<dynamic>> getDeadlines(
    @Path("userId") String userId,
    @Query("startAt") String startAt,
    @Query("endAt") String endAt,
  );

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
  
  @GET("/users/{userId}/courses/{courseId}")
  Future<HttpResponse<dynamic>> getCourse(
    @Path("userId") String userId,
    @Path("courseId") String courseId,
  );

  @POST("/users/{userId}/courses")
  Future<HttpResponse<dynamic>> createCourse(
    @Path("userId") String userId,
    @Body() Map<String, dynamic> courseData,
  );

  @PATCH("/users/{userId}/courses/{courseId}")
  Future<HttpResponse<dynamic>> updateCourse(
    @Path("userId") String userId,
    @Path("courseId") String courseId,
    @Body() Map<String, dynamic> courseData,
  );

  @DELETE("/users/{userId}/courses/{courseId}")
  Future<HttpResponse<void>> deleteCourse(
    @Path("userId") String userId,
    @Path("courseId") String courseId,
  );

  // Schedule endpoints
  @GET("/users/{userId}/schedule")
  Future<HttpResponse<dynamic>> getSchedule(@Path("userId") String userId);

  // Assignment endpoints
  @GET("/users/{userId}/assignments")
  Future<HttpResponse<dynamic>> getAssignments(@Path("userId") String userId);

  @POST("/users/{userId}/courses/{courseId}/assignments")
  Future<HttpResponse<dynamic>> createAssignment(
    @Path("userId") String userId,
    @Path("courseId") String courseId,
    @Body() Map<String, dynamic> assignmentData,
  );

  @PATCH("/users/{userId}/courses/{courseId}/assignments/{assignmentId}")
  Future<HttpResponse<dynamic>> updateAssignment(
    @Path("userId") String userId,
    @Path("courseId") String courseId,
    @Path("assignmentId") String assignmentId,
    @Body() Map<String, dynamic> assignmentData,
  );

  @DELETE("/users/{userId}/courses/{courseId}/assignments/{assignmentId}")
  Future<HttpResponse<void>> deleteAssignment(
    @Path("userId") String userId,
    @Path("courseId") String courseId,
    @Path("assignmentId") String assignmentId,
  );

  // Attachment endpoints
  @POST("/users/{userId}/courses/{courseId}/assignments/{assignmentId}/attachments")
  @MultiPart()
  Future<HttpResponse<dynamic>> uploadAttachment(
    @Path("userId") String userId,
    @Path("courseId") String courseId,
    @Path("assignmentId") String assignmentId,
    @Part(name: "file") File file,
  );

  @GET("/users/{userId}/courses/{courseId}/assignments/{assignmentId}/attachments")
  Future<HttpResponse<dynamic>> getAttachments(
    @Path("userId") String userId,
    @Path("courseId") String courseId,
    @Path("assignmentId") String assignmentId,
  );

  @DELETE("/users/{userId}/courses/{courseId}/assignments/{assignmentId}/attachments/{attachmentId}")
  Future<HttpResponse<void>> deleteAttachment(
    @Path("userId") String userId,
    @Path("courseId") String courseId,
    @Path("assignmentId") String assignmentId,
    @Path("attachmentId") String attachmentId,
  );

  // Events endpoints
  @GET("/users/{userId}/events")
  Future<HttpResponse<dynamic>> getEvents(
    @Path("userId") String userId,
    @Query("startAt") String startAt,
    @Query("endAt") String endAt,
  );

  @POST("/users/{userId}/events/single")
  Future<HttpResponse<dynamic>> createEvent(
    @Path("userId") String userId,
    @Body() Map<String, dynamic> eventData,
  );

  @DELETE("/users/{userId}/events/{eventId}")
  Future<HttpResponse<void>> deleteEvent(
    @Path("userId") String userId,
    @Path("eventId") String eventId,
  );

  @PATCH("/users/{userId}/events/{eventId}")
  Future<HttpResponse<dynamic>> updateEvent(
    @Path("userId") String userId,
    @Path("eventId") String eventId,
    @Body() Map<String, dynamic> eventData,
  );
}