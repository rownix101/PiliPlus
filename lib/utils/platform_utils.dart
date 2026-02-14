import 'dart:io' show Platform;

abstract final class PlatformUtils {
  @pragma("vm:platform-const")
  static final bool isMobile = Platform.isAndroid || Platform.isIOS;

  /// 桌面端支持已停止，始终返回 false
  @pragma("vm:platform-const")
  static final bool isDesktop = false;
}
