import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lazy_notifier.dart';
import 'common.dart';
import 'pages/overview.dart';
import 'pages/dataview.dart';
import 'hide_drawer.dart';
import 'config.dart';
import 'pages/user_side.dart';
import 'pages/readme.dart';
import 'theme.dart';

/// 主页面 响应式布局
class ResponsiveUI extends StatefulWidget {
  const ResponsiveUI({super.key});
  @override
  State<ResponsiveUI> createState() => _ResponsiveUIState();
}

class _ResponsiveUIState extends State<ResponsiveUI> {
  final LazyNotifier<ResponseConfig> sideConfig = LazyNotifier(
    ResponseConfig(sideBuilder: emptyBuilder),
  );

  final LazyNotifier<int> pageIndex = LazyNotifier(0);
  bool? _lastIsLandscape;
  double _landscapeImportWidthRatio = 0.5;
  double? _lastWidth;

  ////!====== 需要修改的 =====!////
  late final userInfoSide = UserInfoSide(
    user: 'zytx121',
    sideConfig: sideConfig,
  ); // 个人信息侧栏
  // 改顺序只需要改index
  late final List<_PageWithIcon> pages = [
    _PageWithIcon(
      title: 'Overview',
      icon: Icons.bar_chart,
      page: OverviewPage(
        key: const ValueKey('overview'),
        sideBuilder: userInfoSide.build,
        sideConfig: sideConfig,
        pageIndex: pageIndex,
        index: 0,
        // owner: Config.owner,
        // repo: Config.repo,
      ),
    ),
    _PageWithIcon(
      title: 'Readme',
      icon: Icons.book,
      page: ReadmePage(
        key: const ValueKey('readme'),
        // sideBuilder: userInfoSide.build, // 也可以自定义侧边栏
        sideConfig: sideConfig,
        pageIndex: pageIndex,
        index: 1,
        // owner: Config.owner,
        // repo: Config.repo,
      ),
    ),
    _PageWithIcon(
      title: 'Dataview',
      icon: Icons.table_chart,
      page: DataviewPage(
        key: const ValueKey('dataview'),
        sideConfig: sideConfig,
        pageIndex: pageIndex,
        index: 2,
        // owner: Config.owner,
        // repo: Config.repo,
      ),
    ),
  ]..sort((a, b) => a.page.index.compareTo(b.page.index));

  late final Widget _mainArea = Expanded(
    key: GlobalKey(), // 必须全局，不然每次切换页面都会重建
    child: ValueListenableBuilder<int>(
      valueListenable: pageIndex,
      builder: (_, index, _) =>
          IndexedStack(index: index, children: [for (final p in pages) p.page]),
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pageIndex.notify();
    });
  }

  @override
  void dispose() {
    super.dispose();
    sideConfig.dispose();
    pageIndex.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 判断为横屏：宽度超大，否则宽度大于高度
    final size = MediaQuery.of(context).size;
    final bool isLandscape =
        size.width >= AppTheme.maxPageWidth || size.width >= size.height;
    _lastIsLandscape ??= isLandscape;
    _lastWidth ??= size.width * 0.9;

    late Widget body;
    if (isLandscape) {
      // 横屏
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      if (_lastIsLandscape != isLandscape) {
        // 从竖屏切换到横屏
        if (sideConfig.value.sideWidthRatio >= 1) {
          // 说明是重要内容 使用上次的比例 实现显示重要内容时横-竖-横后宽度不变
          sideConfig.value.sideWidthRatio = _landscapeImportWidthRatio;
        } else {
          sideConfig.value.sideWidthRatio = 0; // 非重要内容保持默认宽度
          sideConfig.value.close = null;
        }
      }
      body = LayoutBuilder(
        // 手机上由于SafeArea的关系，横屏时宽度不一定是满屏
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          return Row(
            // 横屏左右布局，左侧显示主要内容
            children: [
              _mainArea,
              ValueListenableBuilder<ResponseConfig>(
                valueListenable: sideConfig,
                builder: (context, value, child) {
                  final sideWidth = (value.sideWidthRatio > 0)
                      ? value.sideWidthRatio *
                            maxWidth // 要求的宽度
                      : (size.height * AppTheme.sideWPH).clamp(
                          min(AppTheme.minSideWidth, maxWidth * 0.5).toDouble(),
                          AppTheme.maxSideWidth,
                        ); // 默认宽度
                  Widget childWidget;
                  if (value.showNavigator) {
                    childWidget = Column(
                      children: [
                        Expanded(child: value.sideBuilder(context)),
                        navigatorLandscape(),
                      ],
                    );
                  } else {
                    childWidget = value.sideBuilder(context);
                  }
                  return AnimatedContainer(
                    duration: Config.sideAnimationDuration,
                    curve: Curves.easeInOutSine,
                    width: sideWidth,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        left: BorderSide(color: Color(0xFFE5E5E5), width: 1),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: Config.sideAnimationDuration, // 渐变时长
                      child: childWidget,
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
    } else {
      // 竖屏
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      if (_lastIsLandscape != isLandscape) {
        // 从横屏切换到竖屏
        if (sideConfig.value.sideWidthRatio > 0) {
          // 说明是重要内容 会注册关闭回调，需要保留
          _landscapeImportWidthRatio = sideConfig.value.sideWidthRatio;
          sideConfig.value.sideWidthRatio = 1; // 竖屏保持重要内容显示
        } else {
          sideConfig.value.close = null;
        }
      }
      body = Stack(
        children: [
          // 主要内容
          Column(children: [navigatorPortrait(), _mainArea]),
          // 右侧遮罩
          ValueListenableBuilder<ResponseConfig>(
            valueListenable: sideConfig,
            builder: (context, value, _) {
              final sideWidth = value.sideWidthRatio * size.width;
              final visible = sideWidth > 1;
              if (visible) {
                _lastWidth = sideWidth;
              }
              return Stack(
                children: [
                  // 遮罩层始终存在，动画淡入淡出，透明时不拦截事件
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: sideWidth <= 0,
                      child: GestureDetector(
                        onTap: () {
                          sideConfig.value.sideWidthRatio = 0;
                          sideConfig.notify();
                        },
                        child: AnimatedOpacity(
                          opacity: sideWidth > 0 ? 1.0 : 0.0,
                          duration: Config.sideAnimationDuration,
                          child: Container(color: Colors.black45),
                        ),
                      ),
                    ),
                  ),
                  // 右侧弹窗靠右
                  Align(
                    alignment: Alignment.centerRight,
                    child: RightDrawer(
                      sideWidth: visible ? sideWidth : _lastWidth!, // 右侧宽度
                      visible: visible, // 是否显示
                      child: sideConfig.value.sideBuilder(context), // 右侧内容
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      );
    }
    _lastIsLandscape = isLandscape;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (sideConfig.value.close != null) {
          sideConfig.value.close!();
          sideConfig.value.close = null;
          return;
        }
        // 再次返回则退出应用
        if (_isExitWarning) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          await SystemNavigator.pop(); // 真正退出应用（Android）
          // iOS 上系统自己会处理返回桌面
          return;
        } else {
          _isExitWarning = true;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('再次返回则退出应用')));
          Future.delayed(const Duration(seconds: 2), () {
            _isExitWarning = false;
          });
        }
      },
      child: body,
    );
  }

  bool _isExitWarning = false;

  /// 横屏侧边导航栏
  Widget navigatorLandscape() {
    return ConstrainedBox(
      constraints: const BoxConstraints(), // 不强制拉伸高度
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: pages.length,
        itemBuilder: (context, i) {
          final selected = pageIndex.value == i;
          return InkWell(
            onTap: () => pageIndex.value = i,
            child: Container(
              color: selected ? AppTheme.themeColor.withAlpha(20) : null,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical:
                            Theme.of(context).textTheme.labelMedium?.fontSize ??
                            11,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            pages[i].icon,
                            color: selected
                                ? AppTheme.themeColor
                                : Colors.black38,
                            size: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.fontSize,
                          ),
                          SizedBox(
                            width:
                                Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.fontSize ??
                                14,
                          ),
                          Text(
                            pages[i].title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: selected
                                      ? Colors.black
                                      : Colors.black54,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 右侧高亮竖条
                  Container(
                    width: 6,
                    height:
                        3 *
                        (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16),
                    margin: EdgeInsets.symmetric(
                      vertical:
                          0.5 *
                          (Theme.of(context).textTheme.bodyLarge?.fontSize ??
                              16),
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.themeColor : Colors.black38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 竖屏顶部导航栏
  Widget navigatorPortrait() {
    return SizedBox(
      height: (Theme.of(context).textTheme.titleLarge?.fontSize ?? 22) * 2.7,
      child: ValueListenableBuilder<int>(
        valueListenable: pageIndex,
        builder: (context, selectedIndex, _) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IconButton(
                padding: EdgeInsets.symmetric(
                  horizontal:
                      Theme.of(context).textTheme.labelSmall?.fontSize ?? 9,
                ),
                icon: const Icon(Icons.menu),
                onPressed: () {
                  if (sideConfig.value.sideWidthRatio == 0) {
                    sideConfig.value.sideWidthRatio = 0.84;
                    sideConfig.value.close = () {
                      sideConfig.value.sideWidthRatio = 0;
                      sideConfig.value.close = null;
                      sideConfig.notify();
                    };
                  } else {
                    sideConfig.value.sideWidthRatio = 0;
                    sideConfig.value.close = null;
                  }
                  sideConfig.notify();
                },
              ),
              for (int i = 0; i < pages.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => pageIndex.value = i,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selectedIndex == i
                                ? AppTheme.themeColor
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        pages[i].title,
                        overflow: TextOverflow.fade,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: selectedIndex == i
                              ? Colors.black
                              : Colors.black54,
                          fontWeight: selectedIndex == i
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PageWithIcon {
  final String title;
  final IconData icon;
  final SubPageWidget page;
  _PageWithIcon({required this.title, required this.icon, required this.page});
}
