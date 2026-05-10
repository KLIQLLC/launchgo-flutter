/// Backend permission keys (must match `USER_PERMISSIONS_TYPES` on web / API).
enum UserPermissionType {
  updatePermissions('update-permissions'),

  assignmentCreate('assignment-create'),
  assignmentDelete('assignment-delete'),
  assignmentUpdate('assignment-update'),
  assignmentChangeStatus('assignment-change-status'),
  assignmentManageAttachment('assignment-manage-attachment'),

  chatUse('chat_use'),
  notificationUse('notification_use'),
  logoutUse('logout_use'),

  courseCreate('course-create'),
  courseDelete('course-delete'),
  courseUpdate('course-update'),

  documentCreate('document-create'),
  documentDelete('document-delete'),
  documentUpdate('document-update'),

  eventCreate('event-create'),
  eventDelete('event-delete'),
  eventUpdate('event-update'),
  eventImport('event-import'),
  eventView('event-view'),

  recapCreate('recap-create'),
  recapDelete('recap-delete'),
  recapUpdate('recap-update'),

  exportReportUse('export_report_use');

  const UserPermissionType(this.apiKey);
  final String apiKey;
}

/// Permissions a mentor can toggle for students in the Settings tab (Flutter UI subset).
final List<MentorToggleableStudentPermissionDef> mentorToggleableStudentPermissions = [
  MentorToggleableStudentPermissionDef(
    type: UserPermissionType.eventCreate,
    name: 'Create Events',
    description: 'Allow the user to create events',
  ),
  MentorToggleableStudentPermissionDef(
    type: UserPermissionType.eventUpdate,
    name: 'Update Events',
    description: 'Allow the user to update events',
  ),
  MentorToggleableStudentPermissionDef(
    type: UserPermissionType.eventDelete,
    name: 'Delete Events',
    description: 'Allow the user to delete events',
  ),
];

class MentorToggleableStudentPermissionDef {
  final UserPermissionType type;
  final String name;
  final String description;

  const MentorToggleableStudentPermissionDef({
    required this.type,
    required this.name,
    required this.description,
  });
}

Map<String, bool> parseUserPermissions(dynamic raw) {
  if (raw is! Map) return {};
  final out = <String, bool>{};
  raw.forEach((key, value) {
    final k = key?.toString() ?? '';
    if (k.isEmpty) return;
    out[k] = value == true || value.toString().toLowerCase() == 'true';
  });
  return out;
}

bool permissionMapValue(Map<String, bool>? map, UserPermissionType type) =>
    map?[type.apiKey] ?? false;
