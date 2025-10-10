import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../lazy_notifier.dart';
import '../common.dart';
import '../github_request.dart';
import '../config.dart';
import 'package:http/http.dart' as http;

/// github issue display; 侧边栏不允许自定义
class DataviewPage extends StatefulWidget implements SubPageWidget {
  @override
  final LazyNotifier<ResponseConfig> sideConfig;

  @override
  final int index;

  @override
  final LazyNotifier<int> pageIndex;

  final String owner;
  final String repo;

  const DataviewPage({
    super.key,
    this.owner = Config.owner,
    this.repo = Config.repo,
    required this.sideConfig,
    required this.pageIndex,
    this.index = 0,
  });

  @override
  State<DataviewPage> createState() => _DataviewPageState();
}

class _DataviewPageState extends State<DataviewPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<IssueLabel>? labels;
  Map<String, String> labelColor = {};

  /// 控制搜索页面的刷新
  final LazyNotifier<List<bool>> selectedLabels = LazyNotifier([]);

  final http.Client _client = http.Client();

  List<RawIssue>? latest;
  late final GithubRequester<RawIssue> issueRequester =
      GithubRequester.latestIssueRequester(
        owner: widget.owner,
        repo: widget.repo,
        client: _client,
      );

  final TextEditingController _searchController = TextEditingController();
  GithubRequester<RawIssue>? searcher; // 筛选器
  /// 当前展示的issue列表 控制内容的刷新
  /// 要么等于 latest，要么是search的结果缓存
  /// 从search结果切换到latest（清除筛选条件）记得关掉searcher
  late LazyNotifier<List<RawIssue>> displayedIssues = LazyNotifier([]);

  Future<List<Null>>? inited; // 表明请求已经发起，不代表已经加载
  final ScrollController _listViewController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.pageIndex.addListener(() {
      if (widget.pageIndex.value != widget.index) return;
      // 当前轮到自己了
      inited ??= _init(); // 懒初始化
      widget.sideConfig.value.sideBuilder = sideBuilder;
      widget.sideConfig.notify();
    });
  }

  Future<List<Null>> _init() {
    // 初始化要请求的数据
    final labelInit = IssueLabel.getAllLabels(widget.owner, widget.repo)
        .then((value) {
          labels = value;
          for (var label in value) {
            labelColor[label.name] = label.color;
          }
          selectedLabels.value = List.filled(labels!.length, false);
          displayedIssues.notify();
        })
        .catchError((e) {
          showError(e.toString());
        });
    final issueInit = issueRequester
        .fetchNext()
        .then((issues) {
          latest = issues;
          displayedIssues.value = latest!;
        })
        .catchError((e) {
          showError(e.toString());
        });
    return Future.wait([labelInit, issueInit]);
  }

  @override
  void dispose() {
    super.dispose();
    _client.close();
    selectedLabels.dispose();
    displayedIssues.dispose();
    _searchController.dispose();
    _listViewController.dispose();
  }

  void _requestMore() {
    final loader = displayedIssues.value == latest ? issueRequester : searcher;
    if (loader == null) return;
    if (loader.isLoading || !loader.hasNext) return;
    final p = loader.fetchNext();
    displayedIssues.notify(); // 显示加载动画
    p
        .then((newIssues) {
          if (newIssues.isNotEmpty) {
            displayedIssues.value.addAll(newIssues);
          }
        })
        .catchError((e) {
          showError(e.toString());
        })
        .whenComplete(() {
          displayedIssues.notify();
        });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<List<RawIssue>>(
      valueListenable: displayedIssues,
      builder: (context, issues, _) {
        // 未初始化
        if (labels == null || latest == null) {
          return const Center(child: CircularProgressIndicator());
        }
        // 正在搜索
        if (issues.isEmpty && searcher != null && searcher!.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        // 监听尺寸变化，不然从如果运行时高度增加不会自动加载下一页
        final _ = MediaQuery.of(context).size;
        // 如果内容高度不足以滚动，且还有下一页，自动加载
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_listViewController.hasClients &&
              _listViewController.position.maxScrollExtent == 0) {
            _requestMore();
          }
        });
        return RefreshIndicator(
          onRefresh: () async {
            if (displayedIssues.value == latest) {
              latest!.clear();
              displayedIssues.notify();
              final newIssues = await issueRequester.fetchNext(reset: true);
              latest!.addAll(newIssues);
              displayedIssues.notify();
            } else if (searcher != null) {
              displayedIssues.value.clear();
              displayedIssues.notify();
              displayedIssues.value = await searcher!.fetchNext(reset: true);
            }
            toastification.show(
              type: ToastificationType.success,
              style: ToastificationStyle.flatColored,
              description: Text("Refreshed successfully"),
              alignment: Alignment.bottomCenter,
              autoCloseDuration: const Duration(seconds: 2),
              borderRadius: BorderRadius.circular(12.0),
              showProgressBar: false,
              dragToClose: true,
              applyBlurEffect: true,
            );
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              // 到底部，加载更多
              if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 40) {
                _requestMore();
              }
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              controller: _listViewController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              // 如果在加载中，则多一个item显示加载中
              itemCount: issues.length + (issueRequester.isLoading ? 1 : 0),
              separatorBuilder: (context, index) {
                return const Divider(height: 1, thickness: 0.5, indent: 16);
              },
              itemBuilder: (context, index) {
                if (index < issues.length) {
                  return buildCard(context, issues[index]);
                } else {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _sideDetail(RawIssue issue) {
    final sc = widget.sideConfig;
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    onClose() async {
      sc.value.sideWidthRatio = 0;
      sc.value.showNavigator = true;
      sc.value.close = null;
      // 等待动画结束
      if (!isLandscape) {
        sc.notify();
        await Future.delayed(Config.sideAnimationDuration);
        sc.value.sideBuilder = sideBuilder;
        sc.notify();
      } else {
        sc.value.sideBuilder = sideBuilder;
        sc.notify();
      }
    }

    sc.value.sideBuilder = issue.buildDetail(sc, onClose: onClose);
    sc.value.close = onClose;
    sc.value.sideWidthRatio = isLandscape ? 0.5 : 1;
    sc.value.showNavigator = false;
    sc.notify();
  }

  TextStyle? get _titleTextStyle => Theme.of(context).textTheme.titleMedium;
  double get _titleTextSize => _titleTextStyle?.fontSize ?? 16;
  TextStyle? get _subtitleTextStyle => Theme.of(context).textTheme.bodySmall;
  Widget buildCard(BuildContext context, RawIssue issue) {
    bool isHovered = false; // 闭包的状态
    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: GestureDetector(
            onTap: () => _sideDetail(issue),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                vertical: 0,
                horizontal: _titleTextSize / 1.6,
              ),
              title: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // 鼠标移入有下划线
                  Text(
                    issue.title,
                    // 必须动态获取啊，不然不是最新的
                    style: _titleTextStyle?.copyWith(
                      fontWeight: FontWeight.w600, // 太深了不好看
                      decoration: isHovered ? TextDecoration.underline : null,
                      color: isHovered
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 后面跟标签
                  ...issue.labels.map(
                    (label) => Padding(
                      padding: EdgeInsets.only(left: _titleTextSize / 3),
                      child: IssueLabel(
                        name: label,
                        color: labelColor[label] ?? 'f0f0f0',
                      ).build(context),
                    ),
                  ),
                ],
              ),
              subtitle: (issue.user.isNotEmpty || issue.time.isNotEmpty)
                  ? Text(
                      [
                        if (issue.user.isNotEmpty) '@${issue.user}',
                        if (issue.time.isNotEmpty) 'at ${issue.time}',
                      ].join(' '),
                      style: _subtitleTextStyle?.copyWith(
                        color: Colors.grey[600],
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  void _startSearch() {
    // 得到搜索关键词
    final query = _searchController.text.trim();
    // 得到label信息
    final selected = selectedLabels.value;
    final selectedLabelNames = <String>[];
    if (labels != null) {
      for (var i = 0; i < selected.length; i++) {
        if (selected[i] && i < labels!.length) {
          selectedLabelNames.add(labels![i].name);
        }
      }
    }
    // 判断能否请求
    if (query.isEmpty && selectedLabelNames.isEmpty) {
      searcher = null;
      displayedIssues.value = latest ?? [];
      toastification.show(
        type: ToastificationType.warning,
        style: ToastificationStyle.flatColored,
        title: Text("No filter applied"),
        description: Text(
          "Please enter a keyword or select at least one label!",
        ),
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        borderRadius: BorderRadius.circular(12.0),
        showProgressBar: false,
        dragToClose: true,
        applyBlurEffect: true,
      );
      return;
    }
    // 执行搜索
    searcher = GithubRequester.searchIssueRequester(
      owner: widget.owner,
      repo: widget.repo,
      keyword: query,
      labels: selectedLabelNames,
      client: _client,
    );
    displayedIssues.value = []; // 清空当前显示，显示加载中
    searcher!
        .fetchNext()
        .then((results) {
          displayedIssues.value.addAll(results);
          displayedIssues.notify();
        })
        .catchError((e) {
          showError(e.toString());
        });
    // 搜索后关闭侧边栏
    final size = MediaQuery.of(context).size;
    if (size.width < size.height) {
      widget.sideConfig.value.sideWidthRatio = 0;
      widget.sideConfig.notify();
    }
  }

  void _clearSearchCondition() {
    searcher = null;
    _searchController.clear();
    selectedLabels.value = List.filled(labels!.length, false);
    displayedIssues.value = latest ?? [];
  }

  TextStyle? get _searchTextStyle => Theme.of(context).textTheme.bodyLarge;
  double get _searchTextSize => _searchTextStyle?.fontSize ?? 16;
  Widget sideBuilder(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(_searchTextSize / 1.5),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => _startSearch(),
            style: _searchTextStyle,
            decoration: InputDecoration(
              hintText: 'Search...',
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: EdgeInsets.symmetric(
                horizontal: _searchTextSize * 1.2,
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: _searchTextSize / 3),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: _searchTextSize / 3),
              child: ValueListenableBuilder<List<bool>>(
                valueListenable: selectedLabels,
                builder: (context, selected, _) {
                  if (labels == null) return const SizedBox.shrink();
                  return Wrap(
                    spacing: 5,
                    runSpacing: 3,
                    children: List.generate(labels!.length, (i) {
                      final label = labels![i];
                      final isSelected = (selected.length > i)
                          ? selected[i]
                          : false;
                      return GestureDetector(
                        onTap: () {
                          selectedLabels.value[i] = !selectedLabels.value[i];
                          selectedLabels.notify();
                        },
                        child: label.build(context, selected: isSelected),
                      );
                    }),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: _searchTextSize / 3),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearSearchCondition,
                  icon: const Icon(Icons.refresh, color: Colors.redAccent),
                  label: Text(
                    'Reset',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _startSearch,
                  icon: const Icon(Icons.filter_alt, color: Colors.green),
                  label: Text(
                    'Apply',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
