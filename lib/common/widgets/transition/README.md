# 共享元素过渡动画 (Shared Element Transition)

本目录包含实现视频列表到详情页无缝过渡的动画组件。

## 功能特性

### 1. 共享元素 Hero 动画
使用 Flutter 的 Hero 动画实现从列表页封面图到详情页播放器的无缝过渡。

**核心组件：**
- `SharedElementTransition` - 通用共享元素过渡包装器
- `SharedElementImage` - 图片专用的共享元素组件

**使用方式：**
```dart
// 列表页
Hero(
  tag: heroTag,
  child: NetworkImgLayer(
    src: videoItem.cover,
    width: width,
    height: height,
  ),
)

// 详情页
Hero(
  tag: heroTag,
  child: VideoPlayer(...),
)
```

### 2. 骨架屏过渡 (Skeleton Screen)
在内容加载前显示占位效果，提升用户体验。

**核心组件：**
- `SkeletonScreen` - 基础骨架屏组件
- `VideoDetailSkeleton` - 视频详情页专用骨架屏
- `VideoCardSkeleton` - 视频卡片骨架屏

**使用方式：**
```dart
SkeletonScreen(
  width: 200,
  height: 120,
  shimmer: true, // 开启闪烁效果
)

// 完整页面骨架屏
VideoDetailSkeleton(
  aspectRatio: 16 / 9,
  hasComments: true,
  commentCount: 3,
)
```

### 3. 错落动画 (Staggered Animation)
让多个 UI 元素按时间差依次出现，引导用户视线，让过渡显得有条不紊。

**时间线：**
- T0: 封面图完成共享元素缩放
- T+100ms: 标题和作者信息从下方微弱滑入并淡现
- T+200ms: 评论区和推荐列表向上推入

**核心组件：**
- `StaggeredAnimationGroup` - 错落动画组
- `StaggeredAnimationItem` - 动画项
- `StaggeredFadeIn` - 单个元素的错落动画
- `VideoDetailStaggeredLayout` - 视频详情页预定义布局

**使用方式：**
```dart
StaggeredAnimationGroup(
  children: [
    StaggeredAnimationItem(
      delay: Duration.zero,  // T0
      child: PlayerWidget(),
    ),
    StaggeredAnimationItem(
      delay: Duration(milliseconds: 100),  // T+100ms
      child: TitleSection(),
    ),
    StaggeredAnimationItem(
      delay: Duration(milliseconds: 200),  // T+200ms
      child: CommentsSection(),
    ),
  ],
)
```

### 4. 首帧拦截 (First Frame Interceptor)
解决视频跳转时的黑屏/白屏闪烁问题。

**原理：**
在视频真正开始播放前，显示封面图作为 placeholder，直到播放器回调 `onRenderedFirstFrame` 时，通过 200ms 的淡出效果隐藏封面图，露出实时视频流。

**核心组件：**
- `FirstFrameInterceptor` - 首帧拦截包装器
- `FirstFramePlaceholder` - 首帧占位图
- `SeamlessVideoSwitcher` - 无缝视频切换

**使用方式：**
```dart
FirstFrameInterceptor(
  coverUrl: videoCoverUrl,
  fadeDuration: Duration(milliseconds: 200),
  onFirstFrameRendered: () {
    debugPrint('视频首帧已渲染');
  },
  child: VideoPlayer(...),
)
```

## 综合使用示例

```dart
class VideoDetailPage extends StatelessWidget {
  final String heroTag;
  final String coverUrl;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadingWrapper<VideoDetail>(
        loadingState: controller.loadingState.value,
        skeleton: const VideoDetailSkeleton(),
        builder: (data) {
          return VideoDetailStaggeredLayout(
            player: Hero(
              tag: heroTag,
              child: FirstFrameInterceptor(
                coverUrl: coverUrl,
                child: PLVideoPlayer(...),
              ),
            ),
            titleSection: VideoIntro(data: data),
            commentsSection: CommentsList(data: data.comments),
            relatedVideosSection: RelatedVideos(data: data.related),
          );
        },
      ),
    );
  }
}
```

## 技术细节

### ScaleType 一致性
在变换过程中，保持图片的 `BoxFit` 一致（都是 `BoxFit.cover`），避免拉伸变形。

### 物理效果
给动画加上阻尼感（Damping），让视频窗口在拖动时有一种"重量感"，而不是生硬的线性移动。

### 性能优化
- 使用 `RepaintBoundary` 隔离动画层
- 合理使用 `cacheExtent` 优化列表性能
- 图片使用缩略图减少内存占用

## 文件结构

```
lib/common/widgets/
├── transition/
│   ├── shared_element_transition.dart  # 共享元素过渡
│   └── README.md                        # 本文档
├── skeleton/
│   └── skeleton_screen.dart            # 骨架屏组件
├── animation/
│   └── staggered_animation.dart        # 错落动画
├── player/
│   └── first_frame_interceptor.dart    # 首帧拦截
└── loading/
    └── loading_wrapper.dart            # 加载状态包装器
```

## 注意事项

1. **Hero 动画 tag 必须唯一**：使用 `Utils.makeHeroTag()` 生成唯一标识
2. **内存管理**：在页面销毁时及时释放动画控制器
3. **平台适配**：某些功能（如 TextureView.getBitmap()）需要平台特定实现
4. **网络图片**：确保封面图 URL 有效，否则显示默认占位图
