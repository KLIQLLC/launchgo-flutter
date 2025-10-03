import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../data/recap_repository.dart';
import '../../../../models/recap_model.dart';
import '../../../../services/auth_service.dart';
import 'recap_event.dart';
import 'recap_state.dart';

class RecapBloc extends Bloc<RecapEvent, RecapState> {
  final RecapRepository _repository;
  final AuthService _authService;

  RecapBloc({
    required RecapRepository repository,
    required AuthService authService,
  })  : _repository = repository,
        _authService = authService,
        super(const RecapInitial()) {
    on<LoadRecaps>(_onLoadRecaps);
    on<RefreshRecaps>(_onRefreshRecaps);
    on<CreateRecap>(_onCreateRecap);
    on<UpdateRecap>(_onUpdateRecap);
    on<ShareRecap>(_onShareRecap);
  }

  Future<void> _onLoadRecaps(LoadRecaps event, Emitter<RecapState> emit) async {
    emit(const RecapLoading());
    
    try {
      final recaps = await _repository.getRecaps();
      emit(RecapLoaded(
        recaps: recaps,
        filteredRecaps: recaps,
      ));
    } catch (e) {
      emit(RecapError(message: _getErrorMessage(e)));
    }
  }

  Future<void> _onRefreshRecaps(RefreshRecaps event, Emitter<RecapState> emit) async {
    final currentState = state;
    List<Recap> currentRecaps = [];
    
    if (currentState is RecapLoaded) {
      currentRecaps = currentState.recaps;
      emit(RecapRefreshing(currentRecaps));
    } else {
      emit(const RecapLoading());
    }
    
    try {
      final recaps = await _repository.getRecaps();
      emit(RecapLoaded(
        recaps: recaps,
        filteredRecaps: recaps,
      ));
    } catch (e) {
      emit(RecapError(
        message: _getErrorMessage(e),
        previousRecaps: currentRecaps,
      ));
    }
  }

  Future<void> _onCreateRecap(CreateRecap event, Emitter<RecapState> emit) async {
    emit(const RecapCreating());
    
    try {
      final semesterId = event.semesterId ?? _authService.selectedSemesterId;
      
      final createdRecap = await _repository.createRecap(
        title: event.title,
        notes: event.notes,
        semesterId: semesterId,
      );
      
      emit(RecapCreated(createdRecap));
      
      // Reload recaps to get the updated list
      add(const LoadRecaps());
    } catch (e) {
      emit(RecapCreateError(_getErrorMessage(e)));
    }
  }

  Future<void> _onUpdateRecap(UpdateRecap event, Emitter<RecapState> emit) async {
    emit(RecapUpdating(event.recapId));
    
    try {
      final semesterId = event.semesterId ?? _authService.selectedSemesterId;
      
      final updatedRecap = await _repository.updateRecap(
        recapId: event.recapId,
        title: event.title,
        notes: event.notes,
        semesterId: semesterId,
      );
      
      emit(RecapUpdated(updatedRecap));
      
      // Reload recaps to get the updated list
      add(const LoadRecaps());
    } catch (e) {
      emit(RecapUpdateError(_getErrorMessage(e)));
    }
  }

  Future<void> _onShareRecap(ShareRecap event, Emitter<RecapState> emit) async {
    emit(RecapSharing(event.recap));
    
    try {
      final shareText = _formatShareText(event.recap);
      await Share.share(
        shareText,
        subject: event.recap.title,
      );
      emit(const RecapShared());
    } catch (e) {
      // Share errors are usually not critical, just log them
      emit(const RecapShared());
    }
  }

  String _formatShareText(Recap recap) {
    final dateStr = DateFormat('MMM d, yyyy, hh:mm a').format(recap.createdAt);
    final studentInfo = recap.studentName != null ? '\nStudent: ${recap.studentName}' : '';
    
    return '''${recap.title}
$dateStr$studentInfo

${recap.notes}''';
  }

  String _getErrorMessage(dynamic error) {
    if (error is RecapRepositoryException) {
      return error.message;
    }
    return error.toString();
  }
}