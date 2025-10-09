import 'package:synq_manager/src/models/syncable_entity.dart';

class UserSwitchResult {
  const UserSwitchResult({
    required this.success,
    required this.newUserId,
    this.previousUserId,
    this.unsyncedOperationsHandled = 0,
    this.conflicts,
    this.errorMessage,
  });

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
  final bool success;
  final String? previousUserId;
  final String newUserId;
  final int unsyncedOperationsHandled;
  final List<SyncableEntity>? conflicts;
  final String? errorMessage;
}
