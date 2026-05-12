import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_permission_type.dart';
import '../services/api_service_retrofit.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';

/// Mentor-only: toggles selected student's event permissions (`/settings` shell tab).
class MentorStudentPermissionsScreen extends StatefulWidget {
  const MentorStudentPermissionsScreen({super.key});

  @override
  State<MentorStudentPermissionsScreen> createState() =>
      _MentorStudentPermissionsScreenState();
}

class _MentorStudentPermissionsScreenState
    extends State<MentorStudentPermissionsScreen> {
  Map<String, bool> _permissions = {};
  bool _loadingFetch = false;
  bool _loadingUpdate = false;
  String? _lastFetchedStudentId;
  int _fetchGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final studentId = context.watch<AuthService>().selectedStudentId;
    if (studentId != _lastFetchedStudentId) {
      _lastFetchedStudentId = studentId;
      _load();
    }
  }

  Future<void> _load() async {
    final studentId = context.read<AuthService>().selectedStudentId;
    final api = context.read<ApiServiceRetrofit>();
    if (studentId == null || studentId.isEmpty) {
      setState(() => _permissions = {});
      return;
    }

    final gen = ++_fetchGeneration;
    setState(() => _loadingFetch = true);
    try {
      final map = await api.getUserPermissionsMap(studentId);
      if (!mounted || gen != _fetchGeneration) return;
      setState(() {
        _permissions = map;
        _loadingFetch = false;
      });
    } catch (_) {
      if (!mounted || gen != _fetchGeneration) return;
      setState(() => _loadingFetch = false);
      _toast(context, 'Permissions are NOT fetched', isError: true);
    }
  }

  Future<void> _onToggle(UserPermissionType type, bool value) async {
    final studentId = context.read<AuthService>().selectedStudentId;
    final api = context.read<ApiServiceRetrofit>();
    if (studentId == null || studentId.isEmpty) return;
    if (_loadingUpdate || _loadingFetch) return;

    final prev = Map<String, bool>.from(_permissions);
    setState(() {
      _permissions = {..._permissions, type.apiKey: value};
      _loadingUpdate = true;
    });

    try {
      final next = await api.updateUserPermission(studentId, type.apiKey, value);
      if (mounted) {
        setState(() {
          _permissions = next;
          _loadingUpdate = false;
        });
        _toast(context, 'Permission updated successfully');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _permissions = prev;
          _loadingUpdate = false;
        });
        _toast(context, 'Permission is NOT updated', isError: true);
      }
    }
  }

  void _toast(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _value(UserPermissionType t) => _permissions[t.apiKey] ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final auth = context.watch<AuthService>();
    final studentId = auth.selectedStudentId;

    final busy = _loadingFetch || _loadingUpdate;

    return ColoredBox(
      color: theme.backgroundColor,
      child: SafeArea(
        child: studentId == null || studentId.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Select a student from the menu to manage permissions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textSecondaryColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            : RefreshIndicator(
                color: ThemeService.accent,
                backgroundColor: theme.cardColor,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _PermissionsCard(
                      theme: theme,
                      overlayLoading: _loadingFetch,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield_outlined,
                                  color: theme.textColor, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Permissions',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...mentorToggleableStudentPermissions.map((def) {
                            return SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                def.name,
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                def.description,
                                style: TextStyle(
                                  color: theme.textSecondaryColor,
                                  fontSize: 13,
                                ),
                              ),
                              value: _value(def.type),
                              onChanged: busy
                                  ? null
                                  : (v) => _onToggle(def.type, v),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({
    required this.theme,
    required this.overlayLoading,
    required this.child,
  });

  final ThemeService theme;
  final bool overlayLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.borderColor),
          ),
          child: child,
        ),
        if (overlayLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: theme.backgroundColor.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}
