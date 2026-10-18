import '../../models/auth/inventory_user.dart';

enum InventoryOperation {
  readCandidates,
  readMovements,
  readExplainContext,
  forecast,
  intelligence,
  recommendations,
  analyzeCandidate,
  recommendMovement,
  approveMovement,
  rejectMovement,
  cancelMovement,
  executeMovement,
  explainMovement,
  executionSummary,
  readMarketingRequests,
  decideMarketingRequests,
}

/// UI hints only. Backend account, role, resource and donor checks remain final.
/// Grants nothing to Marketing, customers or any other component.
class InventoryUiPermissions {
  const InventoryUiPermissions(this.user);
  final InventoryUser user;

  bool can(InventoryOperation operation) {
    final role = user.role;
    final analysis = {
      InventoryRole.admin,
      InventoryRole.manager,
      InventoryRole.analyst,
    }.contains(role);
    return switch (operation) {
      InventoryOperation.readCandidates ||
      InventoryOperation.readMovements ||
      InventoryOperation.readExplainContext => true,
      InventoryOperation.forecast ||
      InventoryOperation.intelligence ||
      InventoryOperation.recommendations ||
      InventoryOperation.recommendMovement ||
      InventoryOperation.explainMovement => analysis,
      InventoryOperation.analyzeCandidate => analysis && user.globalAccess,
      InventoryOperation.approveMovement ||
      InventoryOperation.rejectMovement ||
      InventoryOperation.cancelMovement =>
        role == InventoryRole.admin || role == InventoryRole.manager,
      InventoryOperation.executeMovement =>
        role == InventoryRole.admin || role == InventoryRole.operator,
      InventoryOperation.executionSummary => role != InventoryRole.viewer,
      InventoryOperation.readMarketingRequests =>
        role == InventoryRole.admin ||
            role == InventoryRole.manager ||
            role == InventoryRole.analyst,
      InventoryOperation.decideMarketingRequests =>
        role == InventoryRole.admin || role == InventoryRole.manager,
    };
  }

  bool canAccessStores(Iterable<String> stores) {
    final requested = stores.toList();
    return requested.isNotEmpty &&
        requested.every((store) => store.isNotEmpty && store == store.trim()) &&
        (user.globalAccess || requested.every(user.storeIds.contains));
  }

  bool canForStores(InventoryOperation operation, Iterable<String> stores) =>
      can(operation) && canAccessStores(stores);

  bool get canManageUsers =>
      user.role == InventoryRole.admin && user.globalAccess;

  bool get canAccessGlobalReports => user.globalAccess;
}
