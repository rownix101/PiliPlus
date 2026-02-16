# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**PiliPro** is a third-party BiliBili client built with Flutter. It is mobile-first (Android 10+, iOS 17+). Desktop platforms (Windows, Linux, macOS) are deprecated and no longer maintained.

- **Flutter Version**: 3.41.0 (managed via FVM in `.fvmrc`)
- **Dart SDK**: >=3.10.0
- **State Management**: GetX
- **Networking**: Dio with HTTP/2 adapter
- **Video Player**: Native implementation using ExoPlayer (Android) / AVPlayer (iOS) via custom plugin

## Common Commands

```bash
# Install dependencies
flutter pub get

# Run the app (debug mode)
flutter run

# Analyze code
flutter analyze

# Format code (trailing commas preserved per analysis_options.yaml)
dart format .

# Build release APK
flutter build apk --release

# Build release iOS
flutter build ios --release

# Build split APKs per ABI
flutter build apk --release --split-per-abi
```

**Note**: If FVM is installed, prefix commands with `fvm flutter` instead of `flutter`.

## Architecture

### Directory Structure

```
lib/
├── common/           # Shared widgets, constants, skeleton screens, animations
├── grpc/             # Protobuf generated files (DO NOT MODIFY MANUALLY)
├── http/             # API definitions, Dio configuration, interceptors
├── models_new/       # Preferred location for new data models
├── models/           # Legacy models (avoid adding new code here)
├── pages/            # Feature modules (View + Controller pattern)
├── plugin/           # Custom plugins
│   ├── native_player/    # Android/iOS native video player plugin
│   └── pl_player/        # Flutter player UI and controller
├── router/           # GetX route definitions (app_pages.dart)
├── services/         # Global services (Account, Download, Logger)
├── scripts/          # Build scripts and patches
├── tcp/              # TCP/Protobuf streaming
└── utils/            # Utilities (Storage, Extensions, Account management)
```

### Page Structure (GetX Pattern)

Each page in `lib/pages/` follows the View + Controller pattern:

```
lib/pages/my_feature/
├── controller.dart   # GetxController with state and business logic
└── view.dart         # StatelessWidget UI
```

Example:
```dart
// controller.dart
class MyFeatureController extends GetxController {
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize
  }
}

// view.dart
class MyFeaturePage extends StatelessWidget {
  const MyFeaturePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MyFeatureController());
    return Scaffold(
      body: Obx(() => controller.isLoading.value
        ? const Center(child: CircularProgressIndicator())
        : const MyContent()),
    );
  }
}
```

### Networking

- **Request client**: Global `Request()` instance from `lib/http/init.dart`
- **Error handling**: Pass Dio exceptions to `AccountManager.dioError(e)` for standard messaging
- **Logging**: Use the global `logger` from `lib/services/logger.dart` (avoid `print()`)
  - `logger.d('debug message')`
  - `logger.e('error', error: e, stackTrace: s)`

Example API request:
```dart
try {
  final res = await Request().get(Api.myEndpoint);
  if (res.data['code'] == 0) {
    // Success handling
  }
} catch (e) {
  final errorMsg = await AccountManager.dioError(e as DioException);
  logger.e('Failed to fetch data', error: e);
}
```

## Code Style Guidelines

### Imports

**MANDATORY**: Always use **package imports**. Relative imports are strictly forbidden.

- ✅ `import 'package:PiliPro/utils/storage.dart';`
- ❌ `import '../../utils/storage.dart';`

Import order:
1. Flutter/Dart SDK imports
2. Third-party package imports
3. Project imports (package:PiliPro/...)

### Naming Conventions

- **Files**: `snake_case.dart` (e.g., `video_player_controller.dart`)
- **Classes**: `PascalCase` (e.g., `HomeController`)
- **Variables/Methods**: `camelCase` (e.g., `isLogin`, `fetchData()`)
- **Private Members**: Prefix with underscore (e.g., `_internalState`)

### UI Guidelines

- **Material 3**: Use M3 components and dynamic color (`Theme.of(context).colorScheme`)
- **Images**: Use `NetworkImgLayer` for all network images
- **Formatting**: `trailing_commas: preserve` (configured in `analysis_options.yaml`)

## Native Player Plugin

The video player uses a custom native plugin:

- **Android**: ExoPlayer with Media3 (Kotlin)
- **iOS**: AVPlayer (Swift)
- **Flutter interface**: `lib/plugin/native_player/native_player.dart`

Key native files:
- `android/app/src/main/kotlin/com/video/pilipro/NativePlayerPlugin.kt`
- `ios/Runner/NativePlayerPlugin.swift`

The plugin communicates via MethodChannel (`com.pilipro/native_player`) and EventChannel for playback events.

## CI/CD

GitHub Actions workflows in `.github/workflows/`:
- `build.yml`: Android build with APK splitting (arm64-v8a, armeabi-v7a, x86_64)
- `ios.yml`: iOS build

Builds apply Flutter framework patches from `lib/scripts/`:
- `bottom_sheet_patch.diff`
- `modal-barrier-patch.diff`

## Important Notes

- **No test suite**: The project currently has no active test suite (no `test/` directory)
- **Dependency overrides**: Many packages are overridden in `pubspec.yaml` - do not upgrade blindly
- **gRPC**: Managed via protobuf; modifications must be done in source `.proto` files and regenerated
- **API Limits**: Uses unofficial BiliBili APIs - respect rate limits
