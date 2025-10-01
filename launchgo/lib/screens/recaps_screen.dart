import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/recap_model.dart';
import '../services/api_service_retrofit.dart';
import '../services/theme_service.dart';
import '../widgets/recap_card.dart';

class RecapsScreen extends StatefulWidget {
  const RecapsScreen({super.key});

  @override
  State<RecapsScreen> createState() => _RecapsScreenState();
}

class _RecapsScreenState extends State<RecapsScreen> {
  List<Recap> _recaps = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecaps();
  }

  Future<void> _loadRecaps() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final apiService = context.read<ApiServiceRetrofit>();
      final recapsData = await apiService.getRecaps();
      
      final recaps = recapsData.map((data) => Recap.fromJson(data)).toList();
      
      // Sort by createdAt descending (most recent first)
      recaps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      setState(() {
        _recaps = recaps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load recaps: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
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
              onPressed: _loadRecaps,
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
    
    if (_recaps.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
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
                    width: 48,
                    height: 48,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your weekly summaries and\nimportant messages will appear here',
                  style: TextStyle(
                    color: themeService.textSecondaryColor,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openNewRecapForm,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1A1F2B),
          icon: const Icon(Icons.add),
          label: const Text(
            'New Recap',
            style: TextStyle(
              color: Color(0xFF1A1F2B),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadRecaps,
        color: Colors.white,
        backgroundColor: const Color(0xFF1A2332),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _recaps.length,
          itemBuilder: (context, index) {
            final recap = _recaps[index];
            return RecapCard(
              recap: recap,
              onTap: () => _openEditRecapForm(recap),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewRecapForm,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1F2B),
        icon: const Icon(Icons.add),
        label: const Text(
          'New Recap',
          style: TextStyle(
            color: Color(0xFF1A1F2B),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showRecapDetails(Recap recap) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecapDetailsSheet(recap: recap),
    );
  }

  Future<void> _openNewRecapForm() async {
    final result = await context.push('/new-recap');
    
    // Refresh the list if a new recap was created
    if (result == true) {
      _loadRecaps();
    }
  }

  Future<void> _openEditRecapForm(Recap recap) async {
    final result = await context.push(
      '/edit-recap/${recap.id}',
      extra: recap,
    );
    
    // Refresh the list if recap was updated
    if (result == true) {
      _loadRecaps();
    }
  }
}

class _RecapDetailsSheet extends StatelessWidget {
  final Recap recap;

  const _RecapDetailsSheet({required this.recap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF0F1419),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recap.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // TODO: Implement share functionality
                        },
                        icon: const Icon(
                          Icons.share,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (recap.studentName != null) ...[
                    Text(
                      recap.studentName!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDateTime(recap.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    recap.notes,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[date.month - 1];
    final day = date.day;
    final year = date.year;
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    
    return '$month $day, $year, $hour:$minute $period';
  }
}