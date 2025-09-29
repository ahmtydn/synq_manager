# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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