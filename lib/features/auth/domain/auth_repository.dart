import '../../network/domain/network_models.dart';
import '../data/api_auth_repository.dart' show LoginResult;
import 'auth_user.dart';

abstract interface class AuthRepository {
  /// Fetches the public list of active stores for login screen.
  Future<List<LoginStore>> fetchLoginStores();

  /// Login with username/password and optional storeId.
  Future<LoginResult> login(String username, String password, {int? storeId});

  /// Completes an SMS 2FA challenge started by [login].
  Future<LoginResult> verifyTwoFactor({
    required String challengeId,
    required String code,
    required String username,
  });

  /// Restores session from stored JWT if still valid.
  Future<AuthUser?> tryAutoLogin();

  /// Refreshes access token before soft-expiry.
  Future<AuthUser?> tryRefreshSession();

  /// Wipes stored tokens and clears cached auth state.
  Future<void> logout();

  /// Fetches the fresh profile for currently authenticated user.
  Future<AuthUser?> fetchCurrentUser();
}
