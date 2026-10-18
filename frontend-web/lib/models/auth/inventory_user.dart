/// Inventory identity only. Customer and Marketing identities are not accepted.
enum InventoryRole { admin, manager, analyst, operator, viewer }

class InventoryUser {
  InventoryUser._({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.role,
    required this.globalAccess,
    required List<String> storeIds,
  }) : storeIds = List.unmodifiable(storeIds);

  factory InventoryUser.fromJson(Map<String, dynamic> json) {
    final id = json['user_id'];
    final username = json['username_normalized'];
    final display = json['display_name'];
    final roleName = json['role'];
    final global = json['global_access'];
    final stores = json['store_ids'];
    if (id is! String ||
        id.length != 28 ||
        !RegExp(r'^oid:[0-9a-f]{24}$').hasMatch(id) ||
        username is! String ||
        username.isEmpty ||
        username.length > 128 ||
        username != username.trim() ||
        display is! String ||
        roleName is! String ||
        !InventoryRole.values.any((role) => role.name == roleName) ||
        global is! bool ||
        stores is! List ||
        stores.any(
          (store) => store is! String || store.isEmpty || store != store.trim(),
        )) {
      throw const FormatException('Invalid Inventory principal.');
    }
    return InventoryUser._(
      userId: id,
      username: username,
      displayName: display,
      role: InventoryRole.values.byName(roleName),
      globalAccess: global,
      storeIds: stores.cast<String>(),
    );
  }
  final String userId;
  final String username;
  final String displayName;
  final InventoryRole role;
  final bool globalAccess;
  final List<String> storeIds;
}
