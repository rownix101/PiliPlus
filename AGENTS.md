# PiliPro - 项目上下文指南

## 项目概述

**PiliPro** 是一个使用 Flutter 开发的 BiliBili 第三方客户端，支持多平台运行。该项目 fork 自 PiliPalaX，并进行了更激进的修改和优化。

### 主要功能特性

- **视频相关**: 推荐/热门视频列表、视频播放（支持多种手势操作）、弹幕、字幕、画质/音质选择
- **用户相关**: 登录/注册、用户主页、关注/取关、粉丝管理、私信、黑名单
- **动态相关**: 动态发布/转发/评论、图文动态、话题动态
- **收藏相关**: 视频收藏、稍后再看、历史记录
- **直播相关**: 直播间浏览、弹幕发送、直播分区
- **其他功能**: DLNA 投屏、离线缓存、WebDAV 备份、AI 原声翻译、SponsorBlock、超分辨率等

### 适配平台

- [x] Android
- [x] iOS
- [x] iPad
- [x] Windows
- [x] Linux

---

## 技术栈

### 核心技术

- **框架**: Flutter 3.41.0 (Dart >=3.10.0)
- **状态管理**: GetX
- **视频播放**: media_kit (基于 MPV)
- **网络请求**: Dio
- **本地存储**: Hive
- **UI 组件**: Material 3 + 动态取色 (dynamic_color)

### 主要依赖

| 依赖包 | 用途 |
|--------|------|
| `get` | 状态管理、路由管理 |
| `dio` | 网络请求 |
| `media_kit` | 跨平台视频播放 |
| `cached_network_image` | 图片缓存 |
| `canvas_danmaku` | 弹幕渲染 |
| `hive` | 本地键值存储 |
| `flutter_inappwebview` | WebView 组件 |
| `dynamic_color` | Material 3 动态取色 |
| `window_manager` | 桌面端窗口管理 |
| `protobuf` | gRPC 通信 |

---

## 项目结构

```
lib/
├── main.dart              # 应用入口
├── build_config.dart      # 构建配置（版本号、构建时间等）
├── common/                # 公共组件和常量
│   ├── constants.dart     # 应用常量（API Key、样式等）
│   ├── skeleton/          # 骨架屏组件
│   └── widgets/           # 通用 Widget 组件
├── grpc/                  # gRPC 相关
│   ├── bilibili/          # 自动生成的 protobuf 文件
│   └── *.dart             # gRPC 请求封装
├── http/                  # HTTP 网络层
│   ├── api.dart           # API 接口定义
│   ├── init.dart          # Dio 初始化配置
│   ├── danmaku.dart       # 弹幕相关 API
│   ├── video.dart         # 视频相关 API
│   └── ...                # 其他业务 API
├── models/                # 数据模型（旧）
├── models_new/            # 数据模型（新）
├── pages/                 # 页面模块（按功能划分）
│   ├── home/              # 首页
│   ├── video/             # 视频播放页
│   ├── member/            # 用户相关页面
│   ├── dynamics/          # 动态相关页面
│   ├── live/              # 直播相关页面
│   ├── fav/               # 收藏相关页面
│   └── ...                # 其他页面
├── router/                # 路由配置
│   └── app_pages.dart     # 页面路由定义
├── services/              # 服务层
│   ├── account_service.dart    # 账号服务
│   ├── download_service.dart   # 下载服务
│   ├── audio_handler.dart      # 音频播放服务
│   └── ...
├── utils/                 # 工具类
│   ├── storage.dart       # 存储工具
│   ├── theme_utils.dart   # 主题工具
│   └── ...
└── plugin/                # 插件/原生代码桥接

android/                   # Android 平台代码
ios/                       # iOS 平台代码
windows/                   # Windows 平台代码
macos/                     # macOS 平台代码
linux/                     # Linux 平台代码
assets/                    # 静态资源
├── images/                # 图片资源
├── fonts/                 # 字体文件
└── shaders/               # GLSL 超分辨率滤镜
```

---

## 构建与运行

### 环境要求

- Flutter SDK: 3.41.0 (建议使用 FVM 管理)
- Dart SDK: >=3.10.0
- Android SDK (Android 开发)
- Xcode (iOS/macOS 开发)
- Visual Studio (Windows 开发)
- 相关平台原生工具链

### 常用命令

```bash
# 安装依赖
flutter pub get

# 运行应用（调试模式）
flutter run

# 构建 Android APK
flutter build apk --release

# 构建 Android AppBundle
flutter build appbundle --release

# 构建 iOS
flutter build ios --release

# 构建 Windows
flutter build windows --release

# 构建 macOS
flutter build macos --release

# 构建 Linux
flutter build linux --release

# 运行代码分析
flutter analyze

# 格式化代码
flutter format .

# 生成代码（如有代码生成器）
flutter pub run build_runner build
```

### FVM 使用（推荐）

```bash
# 安装 FVM
fvm install

# 使用项目指定 Flutter 版本
fvm flutter pub get
fvm flutter run
```

---

## 开发规范

### 代码风格

项目使用 `flutter_lints` 作为基础 lint 规则，额外启用了以下规则：

- `always_declare_return_types` - 始终声明返回类型
- `always_use_package_imports` - 始终使用 package 导入
- `avoid_print` - 避免使用 print（使用 logger 替代）
- `prefer_const_constructors` - 优先使用 const 构造函数
- `avoid_relative_lib_imports` - 避免相对路径导入
- `camel_case_types` - 类型使用驼峰命名
- 以及其他 Flutter 推荐规则

### 导入规范

- 所有导入必须使用 `package:` 绝对路径
- 禁止相对路径导入（如 `../utils/storage.dart`）
- 使用 `import 'package:PiliPro/...'` 格式

### 命名规范

- **文件命名**: 小写 + 下划线（如 `video_player.dart`）
- **类命名**: 大驼峰（如 `VideoPlayerController`）
- **常量命名**: 小写 + 下划线（如 `default_timeout`）
- **私有成员**: 下划线前缀（如 `_internalMethod`）

### 架构模式

项目采用 **MVC + Service** 混合架构：

- **Model**: 数据模型类（`models/`、`models_new/`）
- **View**: 页面 UI（`pages/*/view.dart`）
- **Controller**: 页面逻辑（`pages/*/controller.dart`）
- **Service**: 跨页面共享服务（`services/`）
- **Http**: 网络层封装（`http/`）

### 状态管理

- 使用 **GetX** 进行状态管理
- 页面控制器继承 `GetxController`
- 服务使用 `Get.lazyPut()` 或 `Get.put()` 注入

---

## 核心模块说明

### 1. 网络层 (`http/`)

- `init.dart`: Dio 初始化配置，包含拦截器、Cookie 管理等
- `api.dart`: 基础 API 配置
- 按业务划分 API 文件（如 `video.dart`、`danmaku.dart`）

### 2. 视频播放 (`pages/video/`)

- 使用 `media_kit` 作为播放器核心
- 支持手势操作（调节亮度/音量、快进/快退、全屏切换）
- 支持弹幕渲染（`canvas_danmaku`）
- 支持超分辨率滤镜（GLSL shaders）

### 3. 用户系统 (`pages/member/`、`services/account_service.dart`)

- 支持多账号登录
- Cookie 管理
- 用户信息同步

### 4. 本地存储 (`utils/storage.dart`)

- 使用 Hive 进行本地存储
- 封装 `GStorage` 类提供全局访问
- 分类存储设置（`SettingBoxKey`）

### 5. 主题系统 (`utils/theme_utils.dart`)

- 支持亮色/暗色模式
- 支持 Material 3 动态取色
- 支持自定义主题色

---

## CI/CD 配置

项目使用 GitHub Actions 进行自动化构建：

- `.github/workflows/build.yml` - 多平台构建工作流
- `.github/workflows/android.yml` - Android 专项构建
- `.github/workflows/ios.yml` - iOS 专项构建
- `.github/workflows/win_x64.yml` - Windows 构建
- `.github/workflows/linux_x64.yml` - Linux 构建
- `.github/workflows/mac.yml` - macOS 构建

---

## 注意事项

1. **API 限制**: 项目使用 BiliBili 公开 API，请遵守相关使用规范
2. **版权说明**: 本项目仅供学习交流，请勿用于商业用途
3. **代码生成**: `lib/grpc/bilibili/` 目录包含自动生成的 protobuf 文件，请勿手动修改
4. **依赖覆盖**: `pubspec.yaml` 中使用了较多 `dependency_overrides`，升级依赖时需谨慎

---

## 相关链接

- **原项目**: [guozhigq/pilipala](https://github.com/guozhigq/pilipala)
- **上游项目**: [orz12/PiliPalaX](https://github.com/orz12/PiliPalaX)
- **API 文档**: [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
