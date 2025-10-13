/// Defines the strategy to use when switching between users.
enum UserSwitchStrategy {
  /// Before switching to the new user, fully synchronize any pending
  /// local changes for the old user. This is the safest default.
  syncThenSwitch,

  /// When switching to the new user, clear all of their existing local data
  /// and then perform a full sync to fetch fresh data from the remote.
  /// Useful for ensuring a clean state.
  clearAndFetch,

  /// If the old user has any unsynced local changes, the switch operation
  /// will fail and return an error. This forces the user or application
  /// to resolve pending data before proceeding.
  promptIfUnsyncedData,

  /// Switch to the new user without modifying any local data for either
  /// the old or new user. Local data is kept as-is.
  keepLocal,
}
