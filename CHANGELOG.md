# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- 🔐 Offline-first authentication:
  - Guest mode that works completely offline
  - Secure credential storage using flutter_secure_storage
  - Account upgrade with data migration
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
- **Security focused**: Encrypted local storage and secure authentication

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
- 🔐 Advanced authentication providers
- 📊 Analytics and metrics collection
- 🌐 GraphQL adapter support
- 💾 Isar storage adapter
- 🔌 Additional cloud service adapters
- 🎨 UI components for common sync patterns