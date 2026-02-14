import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// 触觉反馈类型枚举
enum HapticType {
  /// 轻触 - 用于微交互确认
  lightImpact,

  /// 中等 - 用于重要操作
  mediumImpact,

  /// 重击 - 用于强烈确认
  heavyImpact,

  /// 选择点击 - 用于切换/选择
  selectionClick,

  /// 成功 - 单次轻确认
  success,

  /// 错误 - 三次微振
  error,

  /// 警告 - 双次振动
  warning,

  /// 三连击 - 快速三次轻触
  tripleLike,

  /// 刷新临界点
  refreshTrigger,

  /// 刷新成功
  refreshSuccess,

  /// 边界撞击
  edgeBounce,

  /// 菜单出现
  menuAppear,
}

/// 触觉反馈服务
/// 提供统一的触觉反馈管理，支持多种反馈类型
class HapticService extends GetxService {
  static HapticService get to => Get.find();

  /// 是否启用触觉反馈
  final RxBool _enabled = true.obs;

  bool get isEnabled => _enabled.value;

  set enabled(bool value) => _enabled.value = value;

  /// 触发触觉反馈
  void feedback(HapticType type) {
    if (!_enabled.value) return;

    switch (type) {
      case HapticType.lightImpact:
        HapticFeedback.lightImpact();
        break;
      case HapticType.mediumImpact:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.heavyImpact:
        HapticFeedback.heavyImpact();
        break;
      case HapticType.selectionClick:
        HapticFeedback.selectionClick();
        break;
      case HapticType.success:
        _successFeedback();
        break;
      case HapticType.error:
        _errorFeedback();
        break;
      case HapticType.warning:
        _warningFeedback();
        break;
      case HapticType.tripleLike:
        tripleAction();
        break;
      case HapticType.refreshTrigger:
        HapticFeedback.selectionClick();
        break;
      case HapticType.refreshSuccess:
        _refreshSuccessFeedback();
        break;
      case HapticType.edgeBounce:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.menuAppear:
        HapticFeedback.selectionClick();
        break;
    }
  }

  /// 点赞动画配合触觉（最高点触发）
  Future<void> likeWithHaptic() async {
    if (!_enabled.value) return;
    HapticFeedback.lightImpact();
  }

  /// 三连击专用（长按三连）
  /// 快速三次轻触，模拟"咔哒咔哒咔哒"
  Future<void> tripleAction() async {
    if (!_enabled.value) return;

    for (int i = 0; i < 3; i++) {
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// 错误状态 - 短-长-短 三次微振
  Future<void> _errorFeedback() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
  }

  /// 警告状态 - 双次振动
  Future<void> _warningFeedback() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    HapticFeedback.mediumImpact();
  }

  /// 成功反馈 - 单次轻确认
  Future<void> _successFeedback() async {
    HapticFeedback.lightImpact();
  }

  /// 刷新成功 - 轻-轻 双击感
  Future<void> _refreshSuccessFeedback() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.lightImpact();
  }

  /// 拉动刷新临界点
  void refreshTriggerPoint() {
    feedback(HapticType.refreshTrigger);
  }

  /// 刷新成功
  Future<void> refreshSuccess() async {
    if (!_enabled.value) return;
    await _refreshSuccessFeedback();
  }

  /// 拉到底部撞击
  void edgeBounce() {
    feedback(HapticType.edgeBounce);
  }

  /// 长按菜单出现
  void menuAppear() {
    feedback(HapticType.menuAppear);
  }
}
