import 'package:flutter/material.dart';
import 'lazy_notifier.dart';
import 'package:toastification/toastification.dart';

import 'package:markdown_widget/markdown_widget.dart';
import 'markdown_custom/video.dart';
import 'markdown_custom/more_img.dart';
import 'markdown_custom/custom_node.dart';
import 'markdown_custom/link.dart';
import 'markdown_custom/table.dart';

typedef WBuilder = Widget Function(BuildContext);
WBuilder emptyBuilder = (context) => const SizedBox.shrink();

/// 子页接口
abstract class SubPageWidget extends Widget {
  final int index;
  final LazyNotifier<int> pageIndex; // 通知子页面当前轮到自己了
  final LazyNotifier<ResponseConfig> sideConfig;
  const SubPageWidget({
    super.key,
    required this.sideConfig,
    required this.pageIndex,
    this.index = 0,
  });
}

/// 响应式侧边栏配置
class ResponseConfig {
  /// 管理侧边栏的宽度
  /// 如果是横屏，非正数表示默认宽度；其余为屏幕宽度的比例，表示展示重要内容。其实也就0 0.5 1三种选择，其中 0.5 和 1 都是重要内容的宽度
  /// 如果是竖屏，非正数表示不显示侧栏；其余为屏幕宽度的比例。建议三种取值：0 0.9 1，其中1才是重要内容
  double sideWidthRatio;

  /// 侧边栏显示什么内容
  WBuilder sideBuilder;

  /// 横屏时，侧边栏是否显示导航栏。当竖屏时此参数无效
  bool showNavigator;

  // 展示详情的时候的返回
  VoidCallback? close;

  ResponseConfig({
    this.sideWidthRatio = 0,
    required this.sideBuilder,
    this.showNavigator = true,
    this.close,
  });
}

void showError(String msg) {
  // 要求用ToastificationWrapper包裹
  toastification.show(
    type: ToastificationType.error,
    style: ToastificationStyle.flatColored,
    description: Text(msg),
    alignment: Alignment.topCenter,
    autoCloseDuration: const Duration(seconds: 3),
    borderRadius: BorderRadius.circular(12.0),
    showProgressBar: false,
    dragToClose: true,
    applyBlurEffect: true,
  );
}

// generators可以自定义节点以覆盖原实现，在自定义节点中可以遍历子元素
final mdHtmlSupport = MarkdownGenerator(
  generators: [videoGeneratorWithTag, moreImgGenerator, linkGenerator, tableGenerator],
  textGenerator: (node, config, visitor) =>
      CustomTextNode(node.textContent, config, visitor),
  richTextBuilder: (span) => RichText(text: span),
);