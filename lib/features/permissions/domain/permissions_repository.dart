import 'my_permissions.dart';

abstract class PermissionsRepository {
  Future<MyPermissions> getMyPermissions();
}
