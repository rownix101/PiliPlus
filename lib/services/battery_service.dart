import 'dart:async';

import 'package:PiliPro/utils/platform_utils.dart';
import 'package:PiliPro/utils/storage_pref.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// 电池状态监听服务
/// 用于监听电池状态变化，在省电模式下自动调整应用设置
class BatteryService extends GetxService {
  static BatteryService get to => Get.find<BatteryService>();

  final Battery _battery = Battery();

  /// 当前是否处于省电模式
  final RxBool isInPowerSaveMode = false.obs;

  /// 电池电量百分比
  final RxInt batteryLevel = 0.obs;

  /// 电池状态（充电中、放电等）
  final Rx<BatteryState> batteryState = BatteryState.unknown.obs;

  StreamSubscription<BatteryState>? _batteryStateSubscription;

  /// 用户手动设置的纯黑主题状态（用于恢复）
  bool? _userPureBlackTheme;

  /// 是否已自动切换过纯黑主题
  bool _hasAutoSwitchedToPureBlack = false;

  @override
  void onInit() {
    super.onInit();
    if (PlatformUtils.isMobile) {
      _initBatteryMonitoring();
    }
  }

  @override
  void onClose() {
    _batteryStateSubscription?.cancel();
    super.onClose();
  }

  /// 初始化电池监听
  Future<void> _initBatteryMonitoring() async {
    try {
      // 获取初始电量
      batteryLevel.value = await _battery.batteryLevel;

      // 监听电池状态变化
      _batteryStateSubscription = _battery.onBatteryStateChanged.listen(
        _onBatteryStateChanged,
      );

      // 检查初始省电模式状态
      await _checkPowerSaveMode();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BatteryService init error: $e');
      }
    }
  }

  /// 电池状态变化回调
  void _onBatteryStateChanged(BatteryState state) {
    batteryState.value = state;
    _checkPowerSaveMode();
  }

  /// 检查是否处于省电模式
  /// 
  /// 省电模式判定条件（满足任一）：
  /// 1. 系统处于省电模式（Battery.powerSaveMode）
  /// 2. 低电量（<= 20%）且正在放电
  Future<void> _checkPowerSaveMode() async {
    if (!PlatformUtils.isMobile) return;

    try {
      final level = await _battery.batteryLevel;
      batteryLevel.value = level;

      // 检查系统省电模式
      bool systemPowerSaveMode = false;
      try {
        systemPowerSaveMode = await _battery.isInBatterySaveMode;
      } catch (_) {
        systemPowerSaveMode = false;
      }

      // 判定是否处于省电模式
      final bool isLowBattery = level <= 20;
      final bool isDischarging = batteryState.value == BatteryState.discharging;
      final bool isPowerSaveMode = systemPowerSaveMode || (isLowBattery && isDischarging);

      // 状态变化时处理
      if (isPowerSaveMode != isInPowerSaveMode.value) {
        isInPowerSaveMode.value = isPowerSaveMode;
        _onPowerSaveModeChanged(isPowerSaveMode);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Check power save mode error: $e');
      }
    }
  }

  /// 省电模式状态变化处理
  void _onPowerSaveModeChanged(bool isInPowerSave) {
    if (!Pref.autoPureBlackOnPowerSave) return;

    if (isInPowerSave) {
      // 进入省电模式：自动开启纯黑主题
      if (!_hasAutoSwitchedToPureBlack) {
        _userPureBlackTheme = Pref.isPureBlackTheme;
        if (!_userPureBlackTheme!) {
          _setPureBlackTheme(true);
          _hasAutoSwitchedToPureBlack = true;
        }
      }
    } else {
      // 退出省电模式：恢复用户之前的设置
      if (_hasAutoSwitchedToPureBlack && _userPureBlackTheme != null) {
        _setPureBlackTheme(_userPureBlackTheme!);
        _hasAutoSwitchedToPureBlack = false;
      }
    }
  }

  /// 设置纯黑主题状态
  void _setPureBlackTheme(bool enable) {
    // 通过 storage 设置值，但不直接刷新主题
    // 主题刷新由监听 storage 变化的逻辑处理
    // 这里我们需要触发主题重建
    // 由于 Hive 的监听器无法自动触发 Flutter 主题重建，
    // 我们需要使用 GetX 或 Stream 来通知主题变化

    // 保存设置
    // 注意：这里不直接修改设置，而是通过专门的回调或事件通知 main.dart 重建主题
  }

  /// 手动触发省电模式检查（供外部调用）
  Future<void> checkPowerSaveMode() async {
    await _checkPowerSaveMode();
  }

  /// 获取当前电池信息
  Map<String, dynamic> get batteryInfo => {
    'level': batteryLevel.value,
    'state': batteryState.value.toString(),
    'isInPowerSaveMode': isInPowerSaveMode.value,
  };
}

/// 纯黑主题状态管理
/// 用于在省电模式下自动切换纯黑主题
class PureBlackThemeController extends GetxController {
  static PureBlackThemeController get to => Get.find<PureBlackThemeController>();

  /// 当前是否应用了纯黑主题（包括用户手动开启和自动开启）
  final RxBool isPureBlackApplied = false.obs;

  /// 是否因省电模式自动开启的纯黑主题
  final RxBool isAutoPureBlack = false.obs;

  /// 用户手动设置的纯黑主题值
  bool _userPureBlackSetting = false;

  @override
  void onInit() {
    super.onInit();
    _userPureBlackSetting = Pref.isPureBlackTheme;
    isPureBlackApplied.value = _userPureBlackSetting;

    // 监听省电模式变化
    if (PlatformUtils.isMobile) {
      ever(BatteryService.to.isInPowerSaveMode, _onPowerSaveModeChanged);
    }
  }

  /// 省电模式变化处理
  void _onPowerSaveModeChanged(bool isInPowerSave) {
    if (!Pref.autoPureBlackOnPowerSave) return;

    if (isInPowerSave) {
      // 进入省电模式
      if (!isPureBlackApplied.value) {
        _userPureBlackSetting = Pref.isPureBlackTheme;
        isAutoPureBlack.value = true;
        isPureBlackApplied.value = true;
      }
    } else {
      // 退出省电模式：恢复用户设置
      if (isAutoPureBlack.value) {
        isPureBlackApplied.value = _userPureBlackSetting;
        isAutoPureBlack.value = false;
      }
    }
  }

  /// 获取当前实际使用的纯黑主题状态
  bool get effectivePureBlack => 
      isAutoPureBlack.value ? true : Pref.isPureBlackTheme;

  /// 手动更新用户设置
  void updateUserSetting(bool value) {
    _userPureBlackSetting = value;
    if (!isAutoPureBlack.value) {
      isPureBlackApplied.value = value;
    }
  }
}
