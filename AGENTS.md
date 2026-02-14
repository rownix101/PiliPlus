# PiliPro - Agentic Coding Guide

## Project Overview
**PiliPro** is a high-performance BiliBili third-party client developed with Flutter.
- **Priority**: Mobile-first (Android 10+, iOS 17+).
- **Status**: Desktop platforms (Windows, Linux, macOS) are **DEPRECATED** and no longer maintained.
- **Architecture**: MVC + Service using **GetX** for state management and **Dio** for networking.

---

## Core Commands

### Development & Build
| Task | Command |
|------|---------|
| Install Dependencies | `flutter pub get` |
| Code Generation | `flutter pub run build_runner build --delete-conflicting-outputs` |
| Analyze Code | `flutter analyze` |
| Format Code | `dart format .` |
| Run App (Debug) | `flutter run` |
| Build Android APK | `flutter build apk --release` |
| Build iOS | `flutter build ios --release` |

> **Note**: This project uses **FVM** with Flutter version `3.41.0`. Use `fvm flutter ...` if FVM is installed.

### Testing
- **Status**: Currently, the project has no active test suite. No `test/` directory exists.
- **Single Test**: `flutter test test/path_to_test.dart` (if created)

---

## Code Style & Guidelines

### 1. Naming Conventions
- **Files**: `snake_case.dart` (e.g., `video_player_controller.dart`).
- **Classes**: `PascalCase` (e.g., `HomeController`).
- **Variables/Methods**: `camelCase` (e.g., `isLogin`, `fetchData()`).
- **Private Members**: Prefix with underscore (e.g., `_internalState`).

### 2. Imports
- **MANDATORY**: Always use **package imports**. Relative imports are strictly forbidden.
  - ✅ `import 'package:PiliPro/utils/storage.dart';`
  - ❌ `import '../../utils/storage.dart';`
- Grouping: Flutter/Dart first, then third-party, then project files.

### 3. State Management (GetX)
- **Modular Pages**: Each page in `lib/pages/` should have a directory containing `view.dart` and `controller.dart`.
- **Controllers**: Inherit `GetxController`. Use `onInit`, `onReady`, `onClose`.
- **Injection**: Use `Get.put()`, `Get.lazyPut()`, or `Get.putOrFind()`.
- **Reactivity**: Use `.obs` for variables and wrap UI in `Obx(() => ...)` or `GetBuilder`.

### 4. Networking & Error Handling
- **Client**: Use the global `Request()` instance from `lib/http/init.dart`.
- **Errors**: Dio exceptions must be passed to `AccountManager.dioError(e)` for standard messaging.
- **Logging**: Use the global `logger` from `lib/services/logger.dart`. Avoid `print()`.
  - `logger.d('message')`, `logger.e('error', error: e, stackTrace: s)`.

### 5. UI & Formatting
- **Material 3**: Use M3 components and dynamic color (`Theme.of(context).colorScheme`).
- **Formatting**: `dart format .` with `trailing_commas: preserve` (configured in `analysis_options.yaml`).
- **Images**: Use `NetworkImgLayer` for all network images.

---

## Directory Structure
- `lib/common/`: Shared widgets, constants, skeleton screens.
- `lib/http/`: API definitions and Dio configuration.
- `lib/pages/`: Modular pages (View + Controller).
- `lib/services/`: Global services (Account, Download, Logger).
- `lib/utils/`: Utility classes (Storage, Theme, Extensions).
- `lib/grpc/`: Protobuf generated files (**DO NOT MODIFY MANUALLY**).
- `lib/models_new/`: **Preferred** for new data models.
- `lib/models/`: Legacy models; avoid adding new code here.

---

## Common Patterns & Snippets

### 1. Page Structure (View + Controller)
```dart
// lib/pages/my_feature/controller.dart
class MyFeatureController extends GetxController {
  final RxBool isLoading = false.obs;
  // ...
}

// lib/pages/my_feature/view.dart
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

### 2. API Request Pattern
```dart
try {
  final res = await Request().get(Api.myEndpoint);
  if (res.data['code'] == 0) {
    // success
  }
} catch (e) {
  final errorMsg = await AccountManager.dioError(e as DioException);
  logger.e('Failed to fetch data', error: e);
}
```

---

## CI/CD & Automation
- **GitHub Actions**: `.github/workflows/` (builds for Android/iOS).
- **gRPC**: Managed via protobuf. If modifications are needed, they must be done in the source `.proto` files (usually external) and re-generated.

---

## Important Notes
- **API Limits**: The app uses unofficial BiliBili APIs. Respect rate limits and usage patterns.
- **Dependency Overrides**: Many packages are overridden in `pubspec.yaml`. Do not upgrade them blindly.
- **Dart Version**: SDK `3.10.0+`, Flutter `3.41.0`.

