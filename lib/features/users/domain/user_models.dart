class UserProfile {
  final String id;
  final String fullName;
  final String username;
  final String? email;
  final String? phone;
  final String role;
  final bool active;
  final bool twoFactor;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.username,
    this.email,
    this.phone,
    required this.role,
    required this.active,
    required this.twoFactor,
    required this.createdAt,
  });
}

/// One cell of role×module permission matrix (web `/permissions` parity).
class PermissionCell {
  final String role;
  final String module;
  final bool canView;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final bool canAction;

  const PermissionCell({
    required this.role,
    required this.module,
    required this.canView,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.canAction,
  });

  factory PermissionCell.fromJson(Map<String, dynamic> json) {
    return PermissionCell(
      role: json['role']?.toString() ?? '',
      module: json['module']?.toString() ?? '',
      canView: json['can_view'] == true,
      canCreate: json['can_create'] == true,
      canEdit: json['can_edit'] == true,
      canDelete: json['can_delete'] == true,
      canAction: json['can_action'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'role': role,
    'module': module,
    'can_view': canView,
    'can_create': canCreate,
    'can_edit': canEdit,
    'can_delete': canDelete,
    'can_action': canAction,
  };

  PermissionCell copyWith({
    bool? canView,
    bool? canCreate,
    bool? canEdit,
    bool? canDelete,
    bool? canAction,
  }) {
    return PermissionCell(
      role: role,
      module: module,
      canView: canView ?? this.canView,
      canCreate: canCreate ?? this.canCreate,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      canAction: canAction ?? this.canAction,
    );
  }

  static String keyOf(String role, String module) => '$role:$module';
}

class PermissionMatrix {
  final List<String> modules;
  final List<String> roles;
  final List<String> perms;
  final List<PermissionCell> cells;

  const PermissionMatrix({
    required this.modules,
    required this.roles,
    required this.perms,
    required this.cells,
  });

  factory PermissionMatrix.fromJson(Map<String, dynamic> json) {
    final cellsRaw = json['cells'];
    return PermissionMatrix(
      modules: (json['modules'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      roles: (json['roles'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      perms: (json['perms'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      cells: cellsRaw is List
          ? cellsRaw
                .whereType<Map>()
                .map(
                  (e) => PermissionCell.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
    );
  }

  Map<String, PermissionCell> get cellMap {
    return {for (final c in cells) PermissionCell.keyOf(c.role, c.module): c};
  }
}
