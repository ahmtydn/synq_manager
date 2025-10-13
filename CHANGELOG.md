# Changelog

## [2.2.0]

### Added
- 🔭 **Lifecycle Observers**: Introduced the `SynqObserver` abstract class, allowing you to hook into key lifecycle events. Monitor `save`, `delete`, `sync`, `conflict`, and `userSwitch` operations for advanced logging, analytics, or side-effects.
- 🎧 **Reactive Queries**: Introduced `watchAll`, `watchById`, `watchQuery`, and `watchAllPaginated` on `SynqManager` to provide real-time, reactive streams of data. Your UI can now automatically update when underlying data changes.
- ⚡️ **Efficient Data Checks**: Added `watchCount`, `watchFirst`, and `watchExists` for highly efficient, reactive checks on your data without fetching full lists.
- 🎯 **Partial Synchronization**: New `SyncScope` model allows you to sync a subset of remote data (e.g., by date range), reducing network usage and sync time for large datasets.
- 🔌 **Adapter Stream Support**: `LocalAdapter` and `RemoteAdapter` now support `changeStream()` and reactive `watch*` methods, forming the foundation for real-time capabilities.
- 🧪 **Reactive Query Tests**: Added comprehensive integration tests for `watchAll`, `watchById`, `watchQuery`, and partial sync scopes.
- 🧪 **Observer Tests**: Added integration tests for `SynqObserver` to ensure all lifecycle hooks are called correctly.

### Improved
- 🔄 **Per-Operation Retry Logic**: Sync operations that fail due to transient network errors are now individually retried up to a configurable limit (`maxRetries`), making synchronization more resilient. A single failed item no longer blocks the entire sync queue.
- 🚀 **Example App**: The example app has been completely overhauled to use `StreamBuilder` and the new reactive query methods, demonstrating modern, real-time UI patterns.
- **Switching Tests**: Added robust integration tests for all `UserSwitchStrategy` options (`syncThenSwitch`, `clearAndFetch`, `promptIfUnsyncedData`).
- **User Switch Strategy Execution**: Improved user switch strategy execution by running it before initializing the new user, adding null checks, and enhancing error handling.

### Fixed
- 🐛 **User Switching Strategy**: Corrected the logic for `promptIfUnsyncedData` to properly prevent user switching when unsynced data is present.
- 🐛 **Duplicate Change Processing**: Implemented a data hash check to prevent the same external change from being processed multiple times, avoiding redundant operations.
- 🐛 **Connectivity Check**: Fixed a type error in `ConnectivityChecker` to correctly handle the `List<ConnectivityResult>` returned by `connectivity_plus: ^5.0.0` and newer, ensuring network status is detected correctly.
- 🐛 **macOS Connectivity**: Corrected the plugin registration for `connectivity_plus` on macOS to use `ConnectivityPlusPlugin`.

### Changed
- 🏗️ **Core Refactoring**: Exposed `localAdapter` and `remoteAdapter` publicly on `SynqManager` for easier access and customization in advanced scenarios.
- ⚠️ **Exception Model**: Introduced `NetworkException` to better distinguish retryable network errors from other failures.
- ♻️ **Conflict Detection**: Simplified conflict detection logic by removing an unnecessary time difference check and relying solely on version comparison.
- 📦 **Dependencies**: Updated `build_runner`, `test`, `very_good_analysis`, and `mocktail` dependencies.
- ♻️ **Adapter Naming**: `LocalAdapter` and `RemoteAdapter` `name` property is now dynamic, based on the class's runtime type.

### Documentation
- 📝 **Enhanced README**: Major updates to `README.md` to document the new reactive query APIs, the `SynqObserver` pattern, and the new Schema Migration framework with clear examples.
- 📖 **Example README**: Updated the example app's `README.md` to reflect its new reactive architecture.
- 📝 **Event & Observer Clarity**: Added detailed descriptions and `toString()` methods to all `SyncEvent` classes for easier debugging.

### Style
- 💄 **Code Formatting**: Enforced an 80-character line length across the project for better readability.

### Test
- ✅ **Migration Tests**: Added a comprehensive test suite for the schema migration framework, covering single-step, multi-step, and failure scenarios.
- ✅ **Middleware Tests**: Added comprehensive tests for `SynqMiddleware`, covering all hooks like `transformBeforeSave`, `afterSync`, and `onConflict`.
- ✅ **User Prompt Resolver Tests**: Added tests for `UserPromptResolver` covering all resolution scenarios.
- ✅ **Sync Event Tests**: Added tests to verify the `toString()` output of all `SyncEvent` subclasses.
- ✅ **SynqManager Tests**: Enhanced integration tests for `SynqManager` with better mocking for `save`, `delete`, and `switchUser` methods.

## [2.1.10]
### Added
- 🔑 **Initial User Bootstrap**: Introduced `SynqConfig.initialUserId` so auto-start sync can target a known user without scanning the entire local dataset

### Changed
- ⚙️ **Auto Sync Initialization**: `startAutoSync` now quietly no-ops when the provided user ID is empty, preventing unnecessary argument errors during startup flows that intentionally defer user selection
- 🚀 **Auto Start Strategy**: Auto-start sync now honors the configured initial user instead of loading every local entity up-front, reducing startup work for large data sets

## [2.1.9]
### Fixed
-  Minor dependency updates and maintenance

## [2.1.8]
### Fixed
- 🛡️ **Remote Sync Regression**: Prevent local datasets from being wiped when the remote source returns empty by repopulating remote storage from healthy local data
- 🧪 **Regression Coverage**: Added unit test ensuring empty-remote scenarios keep local data intact and rehydrate the remote store

## [2.1.7]
### Added
- 🔁 **Remote Metadata Persistence**: `RemoteAdapter` now exposes `updateSyncMetadata` so sync runs persist metadata both locally and remotely for accurate comparisons

### Changed
- 🧪 **Integration Coverage**: Updated integration tests and example remote adapter to validate remote metadata synchronization

## [2.1.6]
### Fixed
- 🐛 **Initialization State**: Fixed initialization state flag to be set before async operations to prevent race conditions during setup

## [2.1.5]
### Added
- 🔄 **External Change Detection**: New `changeStream()` method on `LocalAdapter` and `changeStream` getter on `RemoteAdapter` to enable real-time change notifications
- 📡 **Change Detail Model**: New `ChangeDetail<T>` model for representing external data changes with metadata (type, entityId, userId, timestamp, sourceId)
- 🔁 **Automatic Change Synchronization**: SynqManager now automatically subscribes to adapter change streams and applies external changes to local storage
- 🛡️ **Smart Deduplication**: Sophisticated change deduplication system to prevent infinite loops and duplicate processing
- 🔍 **Change Validation**: Multi-level validation checks for external changes (duplicate detection, data currency checks, pending operation checks)

### Changed
- 🏗️ **SynqManager Refactoring**: Major internal refactoring for better maintainability and error handling
- 📝 **Enhanced Documentation**: Comprehensive inline documentation for all public methods and internal components
- 🔒 **Immutable Dependencies**: Core dependencies are now final and immutable after construction
- ⚡ **Improved Initialization**: Better initialization flow with proper error handling and logging
- 🧹 **Better Resource Management**: Enhanced disposal process with subscription cleanup and state validation

### Improved
- 🛠️ **Error Handling**: More robust error handling throughout the codebase with detailed logging
- 🔐 **State Validation**: Added disposal state checks to prevent operations after disposal
- 📊 **Better Logging**: More detailed debug and info logs throughout the synchronization lifecycle
- 🧪 **Type Safety**: Improved type safety with better use of whereType() instead of where() + cast()
- ⚙️ **Configuration**: Better separation of concerns between configuration and runtime state

### Removed
- 🗑️ **RemoteChangeEvent**: Removed in favor of the new `ChangeDetail` model which is more comprehensive and aligned with sync operations

### Fixed
- 🐛 **Null Safety**: Better null handling in change stream subscriptions and error callbacks
- 🔧 **Middleware Error Handling**: Improved error handling in middleware transformations

## [2.1.4]
### Added
- ✨ **Auto-Start Sync**: New `autoStartSync` configuration option to automatically start auto-sync for all users with local data on initialization
- 🔄 **Auto-Start for Multiple Users**: Automatically detects all users with local data and starts auto-sync for each

### Changed
- 🔧 **Config Rename**: Renamed `autoSyncOnConnect` to `autoStartSync` for better clarity
- 🧹 **Removed Unused Config**: Removed `enableRealTimeSync` configuration option that was not being used

### Improved
- ✅ **Enhanced Testing**: Improved integration tests with proper async handling and cleanup
- 🛠️ **Mock Connectivity Checker**: Enhanced mock with proper stream controller and dispose method for better test reliability

### Fixed
- 🐛 **Test Timing**: Fixed test timing issues by adding proper wait for initial events
- 🧪 **Test Cleanup**: Added proper disposal of connectivity checker in tests to prevent resource leaks

## [2.1.3]
### Fixed
- 🐛 **Critical Error Handling**: Fixed catch blocks to properly handle both `Exception` and `Error` types (e.g., `UnimplementedError`)
- ✅ **Lint Compliance**: Updated all catch blocks to use `on Object catch` syntax to comply with Dart linting rules
- 🔧 **onInit Stream**: Error handling in initialization now properly catches all throwable types including `UnimplementedError`
- 🔧 **switchUser**: Error handling in user switching now properly catches all throwable types

### Improved
- 💪 **Robustness**: Enhanced error resilience by catching all error types, not just exceptions

## [2.1.2]
### Fixed
- 🛡️ **Error Handling in onInit**: Added try-catch block in `onInit` stream to gracefully handle errors during initial data fetch
- 🔔 **Error Event Emission**: When initial data fetch fails, a `SyncErrorEvent` is now properly emitted instead of crashing

### Improved
- 💪 **Robustness**: Enhanced error resilience in initialization flow

## [2.1.1]
### Changed
- ✨ **Improved `onInit` API**: Simplified initialization flow - `onInit` stream now automatically fetches and emits initial data on subscription, eliminating the need for manual `listen()` call
- 📝 **Better Documentation**: Enhanced documentation for `onInit` stream with detailed behavior description and usage examples

### Removed
- 🗑️ **Deprecated `listen()` Method**: Removed the standalone `listen()` method as `onInit` stream now handles initialization automatically

## [2.1.0]
### Added
- ⚡ **Socket-Style Listener API**: Introduced `listen(userId)` on `SynqManager` to deliver an initial dataset snapshot followed by live events through existing streams.

### Changed
- 🔄 **Initialization Events**: New `onInit` stream emits `InitialSyncEvent` payloads to mirror Socket.IO-style handshake semantics; consumers now receive the full dataset before incremental updates.
- 🧪 **Integration Coverage**: Updated integration tests to validate the new listener flow and force-refresh behavior.

## [2.0.2]
### Fixed
- Minor bug fixes and improvements


## [2.0.1]
### Changed
- 🔢 **Version-Driven Conflict Resolution**: `LastWriteWinsResolver` now prefers higher numeric versions before falling back to timestamps, enabling accurate ordering after migrating `version` fields to integers.
- 🧪 **Improved Test Coverage**: Added regression tests ensuring version comparison precedence and timestamp fallback behavior.

## [2.0.0]
### Breaking Changes
- ⚠️ **Major Version Bump**: Significant updates and improvements warranting a major version increase
- 🛠️ **API Changes**: Updated APIs for better usability and consistency

## [1.0.16]
### Fixed
🎯 **onInit Callback Issue**: Fixed critical timing issue where onInit callbacks were not being triggered
- Implemented `_waitUntilReady()` helper method in `SynqListeners` to ensure manager is fully initialized before setting up listeners
- Fixed race condition where `connected` event was being emitted before `onInit` listeners were registered
- Enhanced all listener methods (onEvent, onCreate, onUpdate, onDelete, onError) to wait for manager readiness
- Improved `onInit` reliability by ensuring callback is triggered with all existing data once manager is ready
- Better timing control prevents missing initialization events during app startup

### Enhanced
⚡ **Listener Reliability**: Improved event listener setup and management
- All listeners now wait for SynqManager to be fully ready before registration
- Eliminated timing-dependent failures in event subscription
- More robust initialization flow ensures consistent callback behavior
- Better separation of concerns between manager initialization and listener setup


## [1.0.15]

### Fixed
🔧 **User Account Migration Loop**: Fixed critical bug causing infinite sync loops during offline data upload
- Fixed missing user ID persistence in `_uploadLocalData()` function that caused endless account migration cycles
- Added `cloudUserId` parameter to `_uploadLocalData()` method to ensure user ID is properly stored after successful uploads
- Enhanced account conflict resolution to persist user ID in all scenarios (`keepLocalData` action)
- Improved account scenario detection to prevent false positive offline data upload triggers

### Enhanced
🚀 **Sync Reliability**: Improved account migration handling and prevented unnecessary sync repetitions
- Better user ID tracking across different account scenarios (guest sign-in, offline data upload, account switch)
- Enhanced logging and metadata for account scenario debugging
- Optimized sync flow to avoid redundant migration checks after successful user ID persistence

## [1.0.14]

### Fixed
🔄 **Infinite Push Loop**: Fixed critical bug where successful push operations caused infinite sync loops
- Added timestamp buffer (1 second) in `_scanForUntrackedChanges()` to prevent recently synced items from being detected as new changes
- Enhanced `_persistSyncTimestamp()` to clear pending changes after successful timestamp persistence
- Improved `_pushToCloud()` to immediately remove pushed keys from pending changes upon successful completion
- Modified sync strategy to exclude successfully pushed items from remote data application, preventing unnecessary re-writes
- Added `excludeKeys` parameter to `_applyRemoteChanges()` to avoid re-applying data that was just pushed
- Enhanced `StorageService` with `putWithTimestamp()` method for sync operations that preserve original timestamps

### Enhanced
⚡ **Sync Performance**: Significantly improved sync efficiency and reliability
- Eliminated redundant local storage writes after successful push operations
- Prevented timestamp conflicts between local and remote data during sync cycles
- Optimized pending changes tracking to avoid false positives
- Better separation between user-initiated changes and sync-related operations

## [1.0.13]

### Changed
🔄 **Code Structure Refactoring**: Improved code organization and API structure
- Extracted cloud callback types to separate `CloudCallbacks` model file
- Moved `SyncResult` and `SyncStats` classes to dedicated model files for better maintainability
- Enhanced type safety with proper CloudFetchResponse structure including `cloudUserId` field
- Updated example app to demonstrate new CloudFetchResponse format
- Improved export structure in main library file for better API access

### Added
✨ **Enhanced Cloud Integration**: New CloudFetchResponse structure with user identity support
- Added `cloudUserId` field to CloudFetchResponse for better user tracking
- Enhanced metadata support in cloud operations

## [1.0.12]

### Fixed
🔧 **Delete Sync Issue**: Fixed critical bug where deleted items were not being synced to cloud
- Changed delete operation from hard delete to soft delete (marks items as `deleted: true`)
- Added automatic hard delete after successful cloud sync to maintain storage efficiency
- Ensures all delete operations are properly synchronized with cloud services

### Added
🗑️ **Hard Delete Support**: Added `hardDelete()` method for permanent local deletion
- Available in both `SynqManager` and `StorageService`
- Bypasses sync and removes items immediately from local storage
- Should be used with caution as it doesn't sync deletions to cloud

### Enhanced
⚡ **Sync Performance**: Improved sync service to handle deleted items correctly
- Deleted items are now included in pending changes and synced to cloud
- After successful cloud sync, deleted items are automatically hard deleted locally
- Better storage space management with automatic cleanup of synced deletions

## [1.0.11]

### Added
- 📊 **Metadata Storage**: Implemented metadata storage for sync timestamps in SyncService
- 🔄 **Empty SyncData Support**: Enhanced SynqManager and SyncEvent with empty SyncData support
- 🎯 **Recent Data Retrieval**: Improved pending changes retrieval in SyncService to include recent data

### Fixed
- 🔧 **Dependency Management**: Reverted hive_plus_secure dependency to stable version 1.1.14 from git reference
- 🐛 **Debug Logging**: Replaced print statements with debugPrint for better error handling and logging consistency
- 🧹 **Code Cleanup**: Removed debug print statements from storage event handling

### Enhanced
- ⚡ **Storage Service**: Updated StorageService event handling for better performance
- 🛡️ **Error Management**: Improved error handling throughout SynqManager core functionality
- 📈 **Sync Performance**: Enhanced sync service with better metadata tracking and recent data handling

## [1.0.10]

### Added
- 🚀 **DocumentSerializable Support**: Added support for DocumentSerializable interface to SynqManager
- 📄 **Enhanced Serialization**: Improved data serialization capabilities for better document handling
- 🔧 **Storage Service Enhancement**: Major improvements to storage service functionality

### Enhanced
- ⚡ **SynqManager Core Updates**: Refactored core SynqManager implementation for better performance
- 📊 **Storage Service Optimization**: Streamlined storage service operations (258 additions, 272 deletions)
- 🛠️ **Sync Service Improvements**: Enhanced sync service logic for more reliable data synchronization
- 📦 **Model Updates**: Simplified SyncData model implementation
- 🎯 **Example Integration**: Updated example app to demonstrate new DocumentSerializable features

### Technical Improvements
- 🔄 **Code Refactoring**: Major refactoring across core services for better maintainability
- 📋 **API Consistency**: Improved API consistency across storage and sync services
- 🧹 **Code Cleanup**: Removed redundant code and improved overall code quality

## [1.0.9]

### Fixed
- 🔧 **Duplicate Event Emissions**: Fixed critical issue where storage events were being emitted twice
- ⚡ **Event Handling Optimization**: Removed duplicate event emissions from storage service manual triggers
- 🎯 **Watcher-Only Events**: Streamlined event system to only emit events through Hive watcher
- 📊 **Create vs Update Detection**: Improved event type detection to properly distinguish between create and update operations
- 🔄 **Storage Service Refactor**: Cleaned up storage service event emission logic for better performance

### Enhanced
- 🚀 **Single Event Source**: All storage events now flow through a single, consistent watcher mechanism
- 📈 **Better Performance**: Eliminated redundant event processing and improved overall system responsiveness
- 🛡️ **Reliable Event Tracking**: Event listeners now receive exactly one event per operation

## [1.0.8]

### Fixed
- 🔧 **Critical Sync Logic Bug**: Fixed major issue where `cloudFetchFunction` was never called
- ⚡ **Proper Conflict Detection**: Implemented correct conflict detection by fetching remote data first
- 🔄 **Improved Sync Flow**: Restructured sync process to properly use both `cloudFetchFunction` and `cloudSyncFunction`
- 📊 **Separation of Concerns**: `cloudFetchFunction` now only handles data fetching, `cloudSyncFunction` only handles data pushing
- 🚀 **Two-Phase Sync**: Added separate initial sync and incremental sync modes
- 🔍 **Better Pending Changes Logic**: Fixed logic to only track actual pending changes, not all data

### Enhanced
- 🎯 **Cleaner Function Responsibilities**: Each cloud function now has a single, well-defined responsibility
- 📈 **More Efficient Syncing**: Reduced unnecessary data transfers and improved sync performance
- 🛡️ **Robust Conflict Handling**: Conflicts are now properly detected and handled before data corruption

### Breaking Changes
- ⚠️ **CloudSyncFunction Behavior**: `cloudSyncFunction` should now only handle pushing data, not conflict detection

## [1.0.7]

### Added
- 🚀 **Cloud Sync Event Tracking**: Added detailed event emissions for cloud sync operations
- ☁️ **CloudSyncFunction Events**: `cloudSyncStart`, `cloudSyncSuccess`, `cloudSyncError` events
- 📡 **CloudFetchFunction Events**: `cloudFetchStart`, `cloudFetchSuccess`, `cloudFetchError` events
- 📊 **Enhanced Metadata**: Cloud sync/fetch events include detailed metadata (counts, error info, etc.)
- 🎯 **Socket.io Style Cloud Events**: New listener methods `onCloudSyncStart()`, `onCloudSyncSuccess()`, etc.
- 🛡️ **Detailed Error Information**: Cloud sync errors now include operation context and metadata
- 📋 **Example Integration**: Updated example app to demonstrate cloud sync event handling

### Enhanced
- ⚡ **Real-time Cloud Operation Tracking**: Users can now monitor cloud sync progress in real-time
- 🎨 **Better User Experience**: Apps can show specific status for cloud operations ("Pushing to cloud...", etc.)
- 🔍 **Debugging Support**: Enhanced error reporting for cloud sync troubleshooting

## [1.0.6] - 2025-09-24

### Added
- 🚀 **Socket.io Style Event Listeners**: Added Socket.io-like event handling with intuitive API
- ✨ **Builder Pattern Support**: Quick setup with fluent `onInit().onCreate().onUpdate().start()` pattern
- 🎯 **Granular Event Handling**: Separate callbacks for `onInit`, `onCreate`, `onUpdate`, `onDelete` events
- 📡 **Real-time Data Streaming**: `onInit` provides all data, other events provide only changed data
- 🔄 **Sync State Management**: Built-in `onSyncStart` and `onSyncComplete` event handlers
- 🛡️ **Error Handling**: Dedicated `onError` callback for better error management
- 🌐 **Connection State**: `onConnectionChange` for network connectivity monitoring
- 📋 **Comprehensive Documentation**: Added detailed usage guide for Socket.io style API

### Enhanced
- 💡 **Developer Experience**: More intuitive API similar to Socket.io for web developers
- ⚡ **Performance**: Optimized event handling with direct data access instead of full reloads
- 🔧 **Flexibility**: Support for both traditional stream-based and Socket.io style event handling

### Examples
- 📚 **Updated Example App**: Demonstrates Socket.io style usage with real-time note management
- 📖 **Usage Guide**: Created comprehensive guide for Socket.io style implementation

## [1.0.5]

### Added
- 🔧 **Generic Type Serialization**: Added `fromJson` and `toJson` function parameters to `SynqManager.getInstance()`
- 📦 **Custom Object Support**: Improved support for complex custom data types with proper JSON serialization/deserialization
- 🛠️ **Type-Safe Serialization**: Enhanced type safety for generic types T through configurable serialization functions

### Changed
- ⚡ **Breaking Change**: `SynqManager.getInstance()` now accepts optional `fromJson` and `toJson` parameters for custom object serialization
- 📝 **Updated Documentation**: Enhanced README and example documentation with serialization function usage examples

## [1.0.4]

### Enhanced
- 🚀 **Initial Sync Improvement**: First-time connection now automatically syncs all local data to cloud
- 📤 **Complete Data Upload**: When `_lastSyncTimestamp == 0`, all existing local data is included in the initial sync
- 🔄 **Better Sync Logic**: Improved sync behavior for first-time users and fresh installations

## [1.0.3]

- new structure


## [1.0.2]

### Changed
- 📱 **Platform Support**: Limited to Android and iOS only due to WorkManager dependency requirements
- 🧹 Removed desktop and web platform files to reduce package size
- 📝 Updated documentation to reflect mobile-only support

### Removed
- 🗑️ Linux, macOS, Windows, and Web platform support
- 🗑️ Desktop-specific configuration files

## [1.0.1]

### Fixed
- 📝 Updated documentation and examples
- 🐛 Minor bug fixes and improvements
- ✅ Package validation improvements

## [1.0.0]

### Added
- 🎉 Initial release of SynQ Manager
- ⚡ Offline-first synchronization layer for Flutter applications
- 🔀 Real-time and configurable sync policies
- 👤 Guest mode support with account upgrade capability
- 🔄 Background synchronization using WorkManager
- 🔌 Backend-agnostic architecture:
  - CloudAdapter interface for any backend implementation
  - No built-in backend dependencies - complete freedom of choice
  - Examples for REST API, Supabase, Firebase, and more
- 💾 Local storage support:
  - Hive implementation with type adapters
  - Generic LocalStore interface for other storage engines
- ⚔️ Intelligent conflict resolution:
  - Built-in strategies (local wins, remote wins, newer wins, prompt, merge)
  - Custom conflict resolver interface
  - Automatic conflict detection based on versions and timestamps
- 🎯 Type-safe APIs:
  - Generic support for any data model
  - Strongly typed interfaces throughout
  - SyncCacheModel base class for easy integration
- 🧪 Comprehensive testing:
  - Unit tests for all core components
  - Mock implementations for testing
  - Example app demonstrating all features
- 📊 Real-time monitoring:
  - Sync status streams
  - Conflict event streams
  - Network connectivity tracking
- 🚀 Production-ready features:
  - Error handling and retry logic
  - Detailed logging with configurable levels
  - Background task scheduling
  - Memory-efficient data streaming

### Technical Features
- **Mobile platform support**: iOS and Android (WorkManager requirement)
- **Background sync**: Reliable synchronization even when app is closed
- **Network awareness**: Automatic sync when connectivity is restored
- **Data integrity**: Version-based conflict detection and resolution
- **Scalable architecture**: Modular design for easy extension
- **Performance optimized**: Efficient change tracking and delta sync

### Dependencies
- `hive`: Local storage with type adapters
- `isar_plus_flutter_libs`: Additional storage support
- `workmanager`: Background task execution
- `flutter_secure_storage`: Secure credential storage
- `connectivity_plus`: Network state monitoring
- `supabase_flutter`: Optional Supabase integration
- `http`: HTTP client for REST APIs

### Documentation
- Complete README with quick start guide
- API documentation with examples
- Platform-specific setup instructions
- Testing guidelines and examples
- Architecture overview and best practices

### Example App
- Note-taking app demonstrating all features
- Guest mode and account upgrade flow
- Real-time sync with conflict resolution
- Background sync demonstration
- Production-ready code patterns

## [Unreleased]

### Planned Features
- 📱 Enhanced mobile platform support
- 🔄 Incremental sync optimizations
- 📊 Analytics and metrics collection
- 🌐 GraphQL adapter support
- 💾 Isar storage adapter
- 🔌 Additional cloud service adapters
- 🎨 UI components for common sync patterns