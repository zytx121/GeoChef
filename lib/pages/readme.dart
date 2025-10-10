import 'package:flutter/material.dart';
import '../theme.dart';
import '../lazy_notifier.dart';
import '../common.dart';
import 'package:markdown_widget/markdown_widget.dart';
import '../config.dart';
import '../github_request.dart';

/// 显示README的页面 侧边栏可自定义
class ReadmePage extends StatefulWidget implements SubPageWidget {
  @override
  final LazyNotifier<ResponseConfig> sideConfig;

  @override
  final int index;

  @override
  final LazyNotifier<int> pageIndex;

  /// 可以自定义侧边栏，否则使用目录
  final WBuilder? sideBuilder;
  final String owner;
  final String repo;

  const ReadmePage({
    super.key,
    this.owner = Config.owner,
    this.repo = Config.repo,
    required this.sideConfig,
    required this.pageIndex,
    this.index = 0,
    this.sideBuilder,
  });
  @override
  State<ReadmePage> createState() => _ReadmePageState();
}

class _ReadmePageState extends State<ReadmePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? readmeContent;
  Future<Null>? inited;

  final tocController = TocController();

  @override
  void initState() {
    super.initState();
    widget.pageIndex.addListener(() {
      if (widget.pageIndex.value != widget.index) return;
      // 当前轮到自己了
      inited ??= _init(); // 懒初始化
      widget.sideConfig.value.sideBuilder = widget.sideBuilder ?? sideBuilder;
      widget.sideConfig.notify();
    });
  }

  Future<Null> _init() {
    return getReadmeRaw(widget.owner, widget.repo)
        .then((raw) {
          setState(() {
            readmeContent = raw;
          });
        })
        .catchError((e) {
          showError(e.toString());
        });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final _ = MediaQuery.of(context).size; // 监听尺寸变化，强制 rebuild
    if (readmeContent == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return MarkdownWidget(
      data: readmeContent!,
      selectable: true,
      markdownGenerator: mdHtmlSupport,
      config: AppTheme.myMarkdownConfig,
      tocController: tocController,
      padding: const EdgeInsets.all(12.0),
    );
  }

  /// 默认侧边栏：目录
  Widget sideBuilder(BuildContext context) {
    return TocWidget(
      controller: tocController,
      tocTextStyle: Theme.of(context).textTheme.bodyLarge,
      currentTocTextStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
