import '../../../models/recap_model.dart';
import '../../../services/api_service_retrofit.dart';

abstract class RecapRepository {
  Future<List<Recap>> getRecaps();
  Future<Recap> createRecap({
    required String title,
    required String notes,
    String? semesterId,
  });
  Future<Recap> updateRecap({
    required String recapId,
    required String title,
    required String notes,
    String? semesterId,
  });
}

class RecapRepositoryImpl implements RecapRepository {
  final ApiServiceRetrofit _apiService;

  RecapRepositoryImpl(this._apiService);

  @override
  Future<List<Recap>> getRecaps() async {
    try {
      final recapsData = await _apiService.getRecaps();
      final recaps = recapsData.map((data) => Recap.fromJson(data)).toList();
      
      // Sort by createdAt descending (most recent first)
      recaps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return recaps;
    } catch (e) {
      throw RecapRepositoryException('Failed to load recaps: $e');
    }
  }

  @override
  Future<Recap> createRecap({
    required String title,
    required String notes,
    String? semesterId,
  }) async {
    try {
      final recapData = {
        'title': title,
        'notes': notes,
        if (semesterId != null) 'semesterId': semesterId,
      };

      final result = await _apiService.createRecap(recapData);
      if (result == null) {
        throw RecapRepositoryException('No data returned from server');
      }
      
      return Recap.fromJson(result);
    } catch (e) {
      throw RecapRepositoryException('Failed to create recap: $e');
    }
  }

  @override
  Future<Recap> updateRecap({
    required String recapId,
    required String title,
    required String notes,
    String? semesterId,
  }) async {
    try {
      final recapData = {
        'title': title,
        'notes': notes,
        if (semesterId != null) 'semesterId': semesterId,
      };

      final result = await _apiService.updateRecap(recapId, recapData);
      if (result == null) {
        throw RecapRepositoryException('No data returned from server');
      }
      
      return Recap.fromJson(result);
    } catch (e) {
      throw RecapRepositoryException('Failed to update recap: $e');
    }
  }

}

class RecapRepositoryException implements Exception {
  final String message;
  
  const RecapRepositoryException(this.message);
  
  @override
  String toString() => 'RecapRepositoryException: $message';
}