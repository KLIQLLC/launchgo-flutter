import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../models/recap_model.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/theme_service.dart';
import '../widgets/recap_card.dart';
import '../bloc/recap_bloc.dart';
import '../bloc/recap_event.dart';
import '../bloc/recap_state.dart';

// ===== Constants =====
class _RecapConstants {
  static const double fabFontSize = 16.0;
  static const double emptyStateIconSize = 48.0;
  static const double emptyStatePadding = 32.0;
  static const double listPadding = 16.0;
  // Text sizes
  static const double titleFontSize = 18.0;
  static const double subtitleFontSize = 14.0;
  
  // Colors
  static const Color progressIndicatorColor = Colors.white;
  static const Color fabBackgroundColor = Colors.white;
  static const Color fabForegroundColor = Color(0xFF1A1F2B);
  static const Color refreshIndicatorBackgroundColor = Color(0xFF1A2332);
}


// ===== Main Screen =====
class RecapsScreen extends StatefulWidget {
  const RecapsScreen({super.key});

  @override
  State<RecapsScreen> createState() => _RecapsScreenState();
}

class _RecapsScreenState extends State<RecapsScreen> {
  String? _previousSelectedSemesterId;
  String? _previousSelectedStudentId;

  @override
  void initState() {
    super.initState();
    context.read<RecapBloc>().add(const LoadRecaps());
  }

  Future<void> _openNewRecapForm() async {
    final result = await context.push('/new-recap');
    
    // Refresh the list if a new recap was created
    if (result == true && mounted) {
      context.read<RecapBloc>().add(const LoadRecaps());
    }
  }

  Future<void> _openEditRecapForm(Recap recap) async {
    final result = await context.push(
      '/edit-recap/${recap.id}',
      extra: recap,
    );
    
    // Refresh the list if recap was updated
    if (result == true && mounted) {
      context.read<RecapBloc>().add(const LoadRecaps());
    }
  }

  void _onRefresh() {
    context.read<RecapBloc>().add(const RefreshRecaps());
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final authService = context.watch<AuthService>();
    
    // Check if semester or student changed and trigger recaps reload
    final currentSemesterId = authService.selectedSemesterId;
    final currentStudentId = authService.selectedStudentId;
    
    bool shouldReload = false;
    
    if (_previousSelectedSemesterId != currentSemesterId && currentSemesterId != null) {
      _previousSelectedSemesterId = currentSemesterId;
      shouldReload = true;
    }
    
    if (_previousSelectedStudentId != currentStudentId && currentStudentId != null) {
      _previousSelectedStudentId = currentStudentId;
      shouldReload = true;
      debugPrint('🔄 Selected student changed to: $currentStudentId - reloading recaps');
    }
    
    if (shouldReload) {
      // Trigger reload after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<RecapBloc>().add(const LoadRecaps());
      });
    }
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlocBuilder<RecapBloc, RecapState>(
        builder: (context, state) => _buildBody(state, themeService),
      ),
      floatingActionButton: BlocBuilder<RecapBloc, RecapState>(
        builder: (context, state) {
          final fab = _buildFAB(state);
          return fab ?? const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildBody(RecapState state, ThemeService themeService) {
    if (state is RecapLoading) {
      return const _LoadingState();
    }
    
    if (state is RecapRefreshing) {
      return _RecapsList(
        recaps: state.currentRecaps,
        onRefresh: _onRefresh,
        onRecapTap: _openEditRecapForm,
        isRefreshing: true,
      );
    }
    
    if (state is RecapError) {
      if (state.previousRecaps != null && state.previousRecaps!.isNotEmpty) {
        return _RecapsList(
          recaps: state.previousRecaps!,
          onRefresh: _onRefresh,
          onRecapTap: _openEditRecapForm,
          errorMessage: state.message,
        );
      }
      return _ErrorState(
        error: state.message,
        onRetry: () => context.read<RecapBloc>().add(const LoadRecaps()),
        themeService: themeService,
      );
    }
    
    if (state is RecapLoaded) {
      if (state.recaps.isEmpty) {
        return _EmptyState(themeService: themeService);
      }
      return _RecapsList(
        recaps: state.recaps,
        onRefresh: _onRefresh,
        onRecapTap: _openEditRecapForm,
      );
    }
    
    return _EmptyState(themeService: themeService);
  }

  Widget? _buildFAB(RecapState state) {
    if (state is RecapLoading || (state is RecapError && state.previousRecaps == null)) {
      return null;
    }
    
    return FloatingActionButton.extended(
      onPressed: _openNewRecapForm,
      backgroundColor: _RecapConstants.fabBackgroundColor,
      foregroundColor: _RecapConstants.fabForegroundColor,
      icon: const Icon(Icons.add),
      label: const Text(
        'New Recap',
        style: TextStyle(
          color: _RecapConstants.fabForegroundColor,
          fontSize: _RecapConstants.fabFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ===== Loading State Widget =====
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: _RecapConstants.progressIndicatorColor,
      ),
    );
  }
}

// ===== Error State Widget =====
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final ThemeService themeService;

  const _ErrorState({
    required this.error,
    required this.onRetry,
    required this.themeService,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: _RecapConstants.emptyStateIconSize,
            color: themeService.textTertiaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load recaps',
            style: TextStyle(
              color: themeService.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: themeService.cardColor,
              foregroundColor: themeService.textColor,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ===== Empty State Widget =====
class _EmptyState extends StatelessWidget {
  final ThemeService themeService;

  const _EmptyState({required this.themeService});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_RecapConstants.emptyStatePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: themeService.cardColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: themeService.borderColor,
                  width: 1,
                ),
              ),
              child: SvgPicture.asset(
                'assets/icons/ic_recap.svg',
                width: _RecapConstants.emptyStateIconSize,
                height: _RecapConstants.emptyStateIconSize,
                colorFilter: ColorFilter.mode(
                  themeService.textTertiaryColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Recaps Yet',
              style: TextStyle(
                color: themeService.textColor,
                fontSize: _RecapConstants.titleFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your weekly summaries and\nimportant messages will appear here',
              style: TextStyle(
                color: themeService.textSecondaryColor,
                fontSize: _RecapConstants.subtitleFontSize,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Recaps List Widget =====
class _RecapsList extends StatelessWidget {
  final List<Recap> recaps;
  final VoidCallback onRefresh;
  final Function(Recap) onRecapTap;
  final bool isRefreshing;
  final String? errorMessage;

  const _RecapsList({
    required this.recaps,
    required this.onRefresh,
    required this.onRecapTap,
    this.isRefreshing = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        onRefresh();
        // Wait for refresh to complete
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: Colors.white,
      backgroundColor: _RecapConstants.refreshIndicatorBackgroundColor,
      child: Column(
        children: [
          if (errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red.withValues(alpha: 0.1),
              child: Text(
                'Error: $errorMessage',
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(_RecapConstants.listPadding),
              itemCount: recaps.length,
              itemBuilder: (context, index) {
                final recap = recaps[index];
                return RecapCard(
                  recap: recap,
                  onTap: () => onRecapTap(recap),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

