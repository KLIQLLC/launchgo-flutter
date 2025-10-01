import 'package:equatable/equatable.dart';
import '../../../../models/recap_model.dart';

abstract class RecapEvent extends Equatable {
  const RecapEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load all recaps
class LoadRecaps extends RecapEvent {
  const LoadRecaps();
}

/// Event to refresh recaps (pull-to-refresh)
class RefreshRecaps extends RecapEvent {
  const RefreshRecaps();
}

/// Event to create a new recap
class CreateRecap extends RecapEvent {
  final String title;
  final String notes;
  final String? semesterId;

  const CreateRecap({
    required this.title,
    required this.notes,
    this.semesterId,
  });

  @override
  List<Object?> get props => [title, notes, semesterId];
}

/// Event to update an existing recap
class UpdateRecap extends RecapEvent {
  final String recapId;
  final String title;
  final String notes;

  const UpdateRecap({
    required this.recapId,
    required this.title,
    required this.notes,
  });

  @override
  List<Object?> get props => [recapId, title, notes];
}


/// Event to share a recap
class ShareRecap extends RecapEvent {
  final Recap recap;

  const ShareRecap(this.recap);

  @override
  List<Object?> get props => [recap];
}