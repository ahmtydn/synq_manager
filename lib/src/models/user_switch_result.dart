import 'package:synq_manager/src/models/syncable_entity.dart';

/// Result of a user switching operation.
class UserSwitchResult {
  /// Creates a user switch result.
  const UserSwitchResult({
    required this.success,
    required this.newUserId,
    this.previousUserId,
    this.unsyncedOperationsHandled = 0,
    this.conflicts,
    this.errorMessage,
  });

  /// Creates a successful user switch result.
  factory UserSwitchResult.success({
    required String newUserId,
    String? previousUserId,
    int unsyncedOperationsHandled = 0,
    List<SyncableEntity>? conflicts,
  }) {
    return UserSwitchResult(
      success: true,
      previousUserId: previousUserId,
      newUserId: newUserId,
      unsyncedOperationsHandled: unsyncedOperationsHandled,
      conflicts: conflicts,
    );
  }

  /// Creates a failed user switch result.
  factory UserSwitchResult.failure({
    required String newUserId,
    required String errorMessage,
    String? previousUserId,
  }) {
    return UserSwitchResult(
      success: false,
      previousUserId: previousUserId,
      newUserId: newUserId,
      errorMessage: errorMessage,
    );
  }
  
  /// Whether the switch was successful.
  final bool success;
  
  /// Previous user ID.
  final String? previousUserId;
  
  /// New user ID.
  final String newUserId;
  
  /// Number of unsynced operations handled during switch.
  final int unsyncedOperationsHandled;
  
  /// Conflicts encountered during the switch.
  final List<SyncableEntity>? conflicts;
  
  /// Error message if the switch failed.
  final String? errorMessage;
}
