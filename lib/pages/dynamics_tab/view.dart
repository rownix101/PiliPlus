import 'dart:async';

import 'package:PiliPro/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPro/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPro/http/loading_state.dart';
import 'package:PiliPro/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPro/models/common/nav_bar_config.dart';
import 'package:PiliPro/models/dynamics/result.dart';
import 'package:PiliPro/pages/common/common_page.dart';
import 'package:PiliPro/pages/dynamics/controller.dart';
import 'package:PiliPro/pages/dynamics/widgets/dynamic_panel.dart';
import 'package:PiliPro/pages/dynamics_tab/controller.dart';
import 'package:PiliPro/pages/main/controller.dart';
import 'package:PiliPro/utils/extension/get_ext.dart';
import 'package:PiliPro/utils/global_data.dart';
import 'package:PiliPro/utils/waterfall.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waterfall_flow/waterfall_flow.dart'
    hide SliverWaterfallFlowDelegateWithMaxCrossAxisExtent;

class DynamicsTabPage extends StatefulWidget {
  const DynamicsTabPage({super.key, required this.dynamicsType});

  final DynamicsTabType dynamicsType;

  @override
  State<DynamicsTabPage> createState() => _DynamicsTabPageState();
}

class _DynamicsTabPageState
    extends CommonPageState<DynamicsTabPage, DynamicsTabController>
    with AutomaticKeepAliveClientMixin, DynMixin {
  StreamSubscription? _listener;
  late final MainController _mainController = Get.find<MainController>();

  DynamicsController dynamicsController = Get.putOrFind(DynamicsController.new);
  @override
  late final DynamicsTabController controller;

  @override
  bool get wantKeepAlive => true;

  bool get checkPage =>
      _mainController.navigationBars[0] != NavigationBarType.dynamics &&
      _mainController.selectedIndex.value == 0;

  @override
  bool onNotification(UserScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotification(notification);
  }

  @override
  void listener() {
    if (checkPage) {
      return;
    }
    super.listener();
  }

  @override
  void initState() {
    controller = Get.putOrFind(
      () =>
          DynamicsTabController(dynamicsType: widget.dynamicsType)
            ..mid = dynamicsController.mid.value,
      tag: widget.dynamicsType.name,
    );
    super.initState();
    if (widget.dynamicsType == DynamicsTabType.up) {
      _listener = dynamicsController.mid.listen((mid) {
        if (mid != -1) {
          controller
            ..mid = mid
            ..onReload();
        }
      });
    }
  }

  @override
  void dispose() {
    _listener?.cancel();
    dynamicsController.mid.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return onBuild(
      refreshIndicator(
        onRefresh: () {
          dynamicsController.queryFollowUp();
          return controller.onRefresh();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: controller.scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: buildPage(
                Obx(() => _buildBody(controller.loadingState.value)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(LoadingState<List<DynamicItemModel>?> loadingState) {
    return switch (loadingState) {
      Loading() => dynSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? GlobalData().dynamicsWaterfallFlow
                  ? SliverWaterfallFlow(
                      gridDelegate: dynGridDelegate,
                      delegate: SliverChildBuilderDelegate(
                        (_, index) {
                          if (index == response.length - 1) {
                            controller.onLoadMore();
                          }
                          final item = response[index];
                          return DynamicPanel(
                            item: item,
                            onRemove: (idStr) =>
                                controller.onRemove(index, idStr),
                            onBlock: () => controller.onBlock(index),
                            maxWidth: maxWidth,
                            onUnfold: () => controller.onUnfold(item, index),
                          );
                        },
                        childCount: response.length,
                      ),
                    )
                  : SliverList.builder(
                      itemBuilder: (context, index) {
                        if (index == response.length - 1) {
                          controller.onLoadMore();
                        }
                        final item = response[index];
                        return DynamicPanel(
                          item: item,
                          onRemove: (idStr) =>
                              controller.onRemove(index, idStr),
                          onBlock: () => controller.onBlock(index),
                          maxWidth: maxWidth,
                          onUnfold: () => controller.onUnfold(item, index),
                        );
                      },
                      itemCount: response.length,
                    )
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }
}
