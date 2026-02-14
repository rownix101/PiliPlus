import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:PiliPro/services/haptic_service.dart';

/// 长按菜单项配置
class LongPressMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Widget? trailing;

  const LongPressMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.trailing,
  });
}

/// 长按菜单组件
/// 长按时提供"咔哒"触觉反馈，弹出功能菜单
class LongPressMenu extends StatelessWidget {
  final Widget child;
  final List<LongPressMenuItem> items;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final Color? backgroundColor;
  final double borderRadius;
  final EdgeInsets menuPadding;

  const LongPressMenu({
    super.key,
    required this.child,
    required this.items,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.backgroundColor,
    this.borderRadius = 12,
    this.menuPadding = const EdgeInsets.symmetric(vertical: 8),
  });

  void _showMenu(BuildContext context, Offset position) {
    // 菜单出现时触发咔哒触觉
    HapticService.to.menuAppear();

    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    // 计算菜单位置，确保不超出屏幕
    final screenSize = overlay.size;
    const menuWidth = 200.0;
    final menuHeight = items.length * 48.0 + 16;

    double left = position.dx - menuWidth / 2;
    double top = position.dy - menuHeight / 2;

    // 边界检查
    if (left < 10) left = 10;
    if (left + menuWidth > screenSize.width - 10) {
      left = screenSize.width - menuWidth - 10;
    }
    if (top < 10) top = 10;
    if (top + menuHeight > screenSize.height - 10) {
      top = screenSize.height - menuHeight - 10;
    }

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        left,
        top,
        screenSize.width - left - menuWidth,
        screenSize.height - top - menuHeight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      color: backgroundColor ?? Theme.of(context).cardColor,
      items: items.map((item) => _buildMenuItem(context, item)).toList(),
    ).then((_) {
      onLongPressEnd?.call();
    });
  }

  PopupMenuItem<VoidCallback> _buildMenuItem(
    BuildContext context,
    LongPressMenuItem item,
  ) {
    final theme = Theme.of(context);
    final effectiveColor = item.color ?? theme.iconTheme.color;

    return PopupMenuItem<VoidCallback>(
      value: item.onTap,
      onTap: () {
        // 菜单项点击触觉
        HapticFeedback.lightImpact();
        Future.delayed(const Duration(milliseconds: 100), item.onTap);
      },
      child: Row(
        children: [
          Icon(item.icon, color: effectiveColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: effectiveColor,
              ),
            ),
          ),
          if (item.trailing != null) item.trailing!,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        onLongPressStart?.call();
        _showMenu(context, details.globalPosition);
      },
      child: child,
    );
  }
}

/// 简化版长按菜单
/// 使用 BottomSheet 而非 PopupMenu，更适合移动端
class LongPressBottomSheet extends StatelessWidget {
  final Widget child;
  final List<LongPressMenuItem> items;
  final VoidCallback? onLongPressStart;
  final String? title;

  const LongPressBottomSheet({
    super.key,
    required this.child,
    required this.items,
    this.onLongPressStart,
    this.title,
  });

  void _showBottomSheet(BuildContext context) {
    HapticService.to.menuAppear();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BottomSheetContent(
        items: items,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        onLongPressStart?.call();
        _showBottomSheet(context);
      },
      child: child,
    );
  }
}

class _BottomSheetContent extends StatelessWidget {
  final List<LongPressMenuItem> items;
  final String? title;

  const _BottomSheetContent({
    required this.items,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title!,
                style: theme.textTheme.titleSmall,
              ),
            ),
          if (title != null) const Divider(height: 1),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == items.length - 1;

            return Column(
              children: [
                ListTile(
                  leading: Icon(item.icon, color: item.color),
                  title: Text(
                    item.label,
                    style: TextStyle(color: item.color),
                  ),
                  trailing: item.trailing,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    Future.delayed(
                      const Duration(milliseconds: 200),
                      item.onTap,
                    );
                  },
                ),
                if (!isLast) const Divider(height: 1, indent: 56),
              ],
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
