import '../core/auth/inventory_api_client.dart';
import '../core/auth/inventory_session_controller.dart';
import '../models/auth/inventory_user.dart';
import 'inventory_user_management_api_service.dart';

class InventoryProfileApiService {
  InventoryProfileApiService({
    required InventoryApiClient client,
    required this.session,
  }) : transport = InventoryAccountTransport(client, session);
  final InventorySessionController session;
  final InventoryAccountTransport transport;
  Future<InventoryUser> me() async => InventoryUser.fromJson(
    await transport.request('GET', '/inventory-auth/me'),
  );
  Future<int> update(String displayName, {int? revision}) async {
    final data = await transport.request(
      'PATCH',
      '/inventory-auth/me',
      body: {'display_name': displayName, 'revision': ?revision},
    );
    InventoryUser.fromJson(data['user'] as Map<String, dynamic>);
    return data['revision'] as int;
  }

  Future<void> changePassword(
    String current,
    String password,
    String confirmation, {
    int? revision,
  }) async {
    final lease = session.capture();
    final data = await transport.request(
      'POST',
      '/inventory-auth/change-password',
      body: {
        'current_password': current,
        'new_password': password,
        'new_password_confirmation': confirmation,
        'revision': ?revision,
      },
    );
    // Successful password changes revoke the current JWT, even if the response is malformed.
    session.invalidate(lease);
    if (data['reauthentication_required'] != true) {
      throw const InventoryAccountError(503);
    }
  }
}
