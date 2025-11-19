import 'package:equatable/equatable.dart';
import '../../../../models/recap_model.dart';

abstract class RecapState extends Equatable {
  const RecapState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class RecapInitial extends RecapState {
  const RecapInitial();
}

/// Loading state for initial load
class RecapLoading extends RecapState {
  const RecapLoading();
}

/// Loading state for refresh
class RecapRefreshing extends RecapState {
  final List<Recap> currentRecaps;

  const RecapRefreshing(this.currentRecaps);

  @override
  List<Object?> get props => [currentRecaps];
}

/// Successfully loaded recaps
class RecapLoaded extends RecapState {
  final List<Recap> recaps;
  final List<Recap> filteredRecaps;

  const RecapLoaded({
    required this.recaps,
    required this.filteredRecaps,
  });

  @override
  List<Object?> get props => [recaps, filteredRecaps];
}

/// Error state
class RecapError extends RecapState {
  final String message;
  final List<Recap>? previousRecaps;

  const RecapError({
    required this.message,
    this.previousRecaps,
  });

  @override
  List<Object?> get props => [message, previousRecaps];
}

/// Creating a recap
class RecapCreating extends RecapState {
  const RecapCreating();
}

/// Successfully created a recap
class RecapCreated extends RecapState {
  final Recap recap;

  const RecapCreated(this.recap);

  @override
  List<Object?> get props => [recap];
}

/// Failed to create a recap
class RecapCreateError extends RecapState {
  final String message;

  const RecapCreateError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Updating a recap
class RecapUpdating extends RecapState {
  final String recapId;

  const RecapUpdating(this.recapId);

  @override
  List<Object?> get props => [recapId];
}

/// Successfully updated a recap
class RecapUpdated extends RecapState {
  final Recap recap;

  const RecapUpdated(this.recap);

  @override
  List<Object?> get props => [recap];
}

/// Failed to update a recap
class RecapUpdateError extends RecapState {
  final String message;

  const RecapUpdateError(this.message);

  @override
  List<Object?> get props => [message];
}


/// Sharing a recap
class RecapSharing extends RecapState {
  final Recap recap;

  const RecapSharing(this.recap);

  @override
  List<Object?> get props => [recap];
}

/// Successfully shared a recap
class RecapShared extends RecapState {
  const RecapShared();
}