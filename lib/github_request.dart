import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'lazy_notifier.dart';
import 'package:http/http.dart' as http;
import 'long_press_copy.dart';
import 'common.dart';
import 'package:markdown_widget/markdown_widget.dart';

import 'theme.dart';

/// 需搭配 https://github.com/zytx121/issueStat 使用
/// 形如: {
///     "total": 10,
///     "labels": {
///         "help wanted":4,
///         "question":4,
///         "bug":4,
///     },
///     "recentCreatedAt": [10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
///     "updated": "2025-09-29T15:02:00.947Z"
/// }
/// 用于首页展示
Future<DashboardStat> getDashboardStat(
  final String owner,
  final String repo,
) async {
  final refUrl =
      'https://api.github.com/repos/$owner/$repo/git/refs/tags/dashboard';
  final refResp = await http.get(Uri.parse(refUrl));
  if (refResp.statusCode != 200) {
    if (refResp.statusCode == 403) {
      throw Exception("getTag API rate limit exceeded ╥﹏╥");
    }
    throw Exception("network request failed ╥﹏╥");
  }
  final refData = jsonDecode(refResp.body);
  final tagSha = refData['object']['sha'];

  final tagUrl = 'https://api.github.com/repos/$owner/$repo/git/tags/$tagSha';
  final tagResp = await http.get(Uri.parse(tagUrl));
  if (tagResp.statusCode != 200) {
    if (tagResp.statusCode == 403) {
      throw Exception("getTagInfo API rate limit exceeded ╥﹏╥");
    }
    throw Exception("network request failed ╥﹏╥");
  }
  final tagData = jsonDecode(tagResp.body);
  final msg = tagData['message'];

  final stat = jsonDecode(msg);
  // 将 updated 字段转为 DateTime 对象
  if (stat['updated'] != null) {
    stat['updated'] = DateTime.parse(stat['updated']);
  }
  return DashboardStat.fromMap(stat);
}

class DashboardStat {
  final int total;
  final Map<String, int> labels;
  final List<int> recentCreatedAt; // 最近30天每天创建的issue数量
  final DateTime updated;

  DashboardStat({
    required this.total,
    required this.labels,
    required this.recentCreatedAt,
    required this.updated,
  });

  static DashboardStat fromMap(final Map<String, dynamic> map) {
    return DashboardStat(
      total: map['total'] ?? 0,
      labels:
          (map['labels'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value as int),
          ) ??
          {},
      recentCreatedAt:
          (map['recentCreatedAt'] as List<dynamic>?)
              ?.whereType<int>()
              .toList() ??
          List.filled(30, 0),
      updated: map['updated'] is DateTime
          ? map['updated']
          : DateTime.tryParse(map['updated'] ?? '') ?? DateTime.now(),
    );
  }

  /// 获取从now开始向前days天内的创建数
  int createdInPastDays(final int days, [DateTime? now]) {
    now ??= DateTime.now();
    final int diff = now.difference(updated).inDays;
    int end = days - diff;
    if (end >= recentCreatedAt.length) {
      end = recentCreatedAt.length - 1;
      debugPrint(
        'Warning: days exceed recentCreatedAt length, truncating to ${recentCreatedAt.length}',
      );
    }
    // recentCreatedAt[0]是updated那天，recentCreatedAt[1]是前一天
    int sum = 0;
    for (int i = 0; i <= end; i++) {
      sum += recentCreatedAt[i];
    }
    return sum;
  }
}

/// 获取指定仓库的 README.md 的原始内容
Future<String> getReadmeRaw(final String owner, final String repo) async {
  final url = 'https://api.github.com/repos/$owner/$repo/readme';
  final resp = await http.get(
    Uri.parse(url),
    headers: {'Accept': 'application/vnd.github.v3.raw'},
  );
  if (resp.statusCode != 200) {
    if (resp.statusCode == 403) {
      throw Exception("API rate limit exceeded ╥﹏╥");
    }
    throw Exception("network request failed ╥﹏╥");
  }
  return utf8.decode(resp.bodyBytes);
}

/// 获取指定用户的个人信息
Future<Map<String, dynamic>> getUserInfo(final String user) async {
  final url = 'https://api.github.com/users/$user';
  final resp = await http.get(Uri.parse(url));
  if (resp.statusCode != 200) {
    if (resp.statusCode == 403) {
      throw Exception("API rate limit exceeded ╥﹏╥");
    }
    throw Exception("network request failed ╥﹏╥");
  }
  final data = jsonDecode(utf8.decode(resp.bodyBytes));
  if (data is Map<String, dynamic>) {
    return data;
  } else {
    throw Exception("data format error: ${data.runtimeType}");
  }
}

/// github请求封装，支持分页
class GithubRequester<T> {
  final String baseUrl;
  final http.Client? client; // 允许传入自定义的client以提升性能
  String _nextUrl = "";
  int perPage;
  int issueNumber = -1; // 记录总共请求了多少个issues -1表示没开始
  bool isLoading = false;
  final List<T> Function(List<dynamic>) parseGithub;

  GithubRequester({
    this.perPage = 20,
    required this.baseUrl,
    required this.parseGithub,
    this.client,
  });

  static GithubRequester<RawIssue> latestIssueRequester({
    int perPage = 20,
    required String owner,
    required String repo,
    http.Client? client,
  }) {
    return GithubRequester<RawIssue>(
      perPage: perPage,
      baseUrl: "https://api.github.com/repos/$owner/$repo/issues",
      parseGithub: RawIssue.parseGithub,
      client: client,
    );
  }

  static GithubRequester<RawIssue> searchIssueRequester({
    int perPage = 100,
    required String owner,
    required String repo,
    String keyword = '',
    List<String> labels = const [],
    http.Client? client,
  }) {
    final query = [
      if (keyword.trim().isNotEmpty) Uri.encodeComponent(keyword),
      'state:open',
      'repo:$owner/$repo',
      ...labels.map((e) => 'label:"${Uri.encodeComponent(e)}"'),
    ].join('+');
    final url = 'https://api.github.com/search/issues?q=$query';
    return GithubRequester<RawIssue>(
      perPage: perPage,
      baseUrl: url,
      parseGithub: RawIssue.parseGithub,
      client: client,
    );
  }

  static GithubRequester<IssueComment> issueCommentRequester({
    int perPage = 20,
    required String
    issueUrl, // 形如 https://api.github.com/repos/zytx121/je/issues/1
    http.Client? client,
  }) {
    return GithubRequester<IssueComment>(
      perPage: perPage,
      baseUrl: '$issueUrl/comments',
      parseGithub: IssueComment.parseGithub,
      client: client,
    );
  }

  int get pageNext => (issueNumber ~/ perPage) + 1;
  bool get hasNext => _nextUrl.isNotEmpty || issueNumber < 0;

  String makeUrl() {
    String url = baseUrl;
    if (url.endsWith('?') || url.endsWith('&')) {
      return "${url}per_page=$perPage&page=$pageNext";
    }
    final separator = url.contains('?') ? '&' : '?';
    return "$url${separator}per_page=$perPage&page=$pageNext";
  }

  /// 从响应头中解析出下一页的链接
  /// 如果没有下一页，返回null
  static String? nextPageUrl(http.Response response) {
    final linkHeader = response.headers['link'];
    if (linkHeader != null) {
      final links = linkHeader.split(',');
      for (var link in links) {
        if (link.contains('rel="next"')) {
          int start = link.indexOf('<') + 1;
          return link.substring(start, link.indexOf('>', start));
        }
      }
    }
    return null;
  }

  Future<List<T>> fetchNext({bool reset = false}) async {
    if (isLoading) throw StateError("searching now (/ﾟДﾟ)/");
    if (reset) {
      issueNumber = -1;
      _nextUrl = "";
    }
    if (!hasNext) throw StateError("no more ╮(๑•́ ₃•̀๑)╭");
    if (issueNumber < 0) issueNumber = 0;
    isLoading = true;
    final String url = _nextUrl.isEmpty ? makeUrl() : _nextUrl;
    final http.Response response;
    debugPrint('@fetching $url');
    try {
      if (client == null) {
        response = await http.get(Uri.parse(url));
      } else {
        response = await client!.get(Uri.parse(url));
      }
    } catch (e) {
      isLoading = false;
      throw Exception("network request failed ╥﹏╥");
    }
    isLoading = false;

    if (response.statusCode != 200) {
      if (response.statusCode == 403) {
        throw Exception("API rate limit exceeded ╥﹏╥");
      }
      throw Exception("network request failed ╥﹏╥");
    }

    // 获取下一页的链接，因为page大了会请求失败
    _nextUrl = GithubRequester.nextPageUrl(response) ?? "";

    final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
    late final List<T> result;
    // 兼容最新和搜索两种接口
    if (decoded is List) {
      result = parseGithub(decoded);
    } else if (decoded is Map<String, dynamic> &&
        decoded.containsKey('items') &&
        decoded['items'] is List) {
      result = parseGithub(decoded['items']);
    } else {
      throw Exception("data format error: ${decoded.runtimeType}");
    }
    issueNumber += result.length;
    return result;
  }
}

class IssueLabel {
  final String name;
  final String color;
  final String description;

  IssueLabel({required this.name, required this.color, this.description = ''});

  Widget build(BuildContext context, {bool selected = false}) {
    final baseColor = Color(int.parse('0xff$color'));
    final borderColor = selected
        ? HSLColor.fromColor(baseColor)
              .withLightness(
                (HSLColor.fromColor(baseColor).lightness * 0.7).clamp(0.0, 1.0),
              )
              .toColor()
        : Colors.transparent;
    final boxShadow = selected
        ? [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ]
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      margin: const EdgeInsets.only(right: 4, bottom: 2),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(99), // 胶囊形状
        border: Border.all(color: borderColor, width: 2),
        boxShadow: boxShadow,
      ),
      child: Text(
        name,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color:
              ThemeData.estimateBrightnessForColor(baseColor) == Brightness.dark
              ? Colors.white
              : Colors.black,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  static List<IssueLabel> parseGithub(List<dynamic> rawLabelList) {
    List<IssueLabel> result = [];
    for (var label in rawLabelList) {
      if (label is Map<String, dynamic> &&
          label['name'] != null &&
          label['name'].toString().isNotEmpty) {
        result.add(
          IssueLabel(
            name: label['name'] ?? '',
            color: label['color'] ?? 'f0f0f0',
            description: label['description'] ?? '',
          ),
        );
      }
    }
    return result;
  }

  // label 没有分页请求的习惯 一次性全部获取
  static Future<List<IssueLabel>> getAllLabels(
    String owner,
    String repo,
  ) async {
    String? url = 'https://api.github.com/repos/$owner/$repo/labels';
    List<IssueLabel> result = [];
    while (url != null) {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        if (resp.statusCode == 403) {
          throw Exception("getLabel API rate limit exceeded ╥﹏╥");
        }
        throw Exception("network request failed ╥﹏╥");
      }
      final List<dynamic> data = jsonDecode(utf8.decode(resp.bodyBytes));
      result.addAll(IssueLabel.parseGithub(data));
      url = GithubRequester.nextPageUrl(resp);
    }
    return result;
  }
}

class RawIssue {
  final String url; // 供获取comments的 api url
  final String title;
  final String user;
  final String time;
  final String raw;
  final List<String> labels;
  final List<IssueComment> comments = [];
  GithubRequester<IssueComment>? _commentRequester;

  RawIssue({
    required this.url,
    required this.title,
    required this.user,
    required this.time,
    required this.raw,
    this.labels = const [],
  });

  static List<RawIssue> parseGithub(List<dynamic> rawIssueList) {
    List<RawIssue> result = [];
    for (var issue in rawIssueList) {
      if (issue is Map<String, dynamic>) {
        result.add(
          RawIssue(
            url: issue['url'] ?? '',
            title: issue['title'] ?? '',
            user: issue['user']?['login'] ?? '',
            time: issue['created_at'] ?? '',
            raw: issue['body'] ?? '',
            labels:
                (issue['labels'] as List<dynamic>?)
                    ?.whereType<Map<String, dynamic>>()
                    .map((label) => label['name'] as String? ?? '')
                    .toList() ??
                [],
          ),
        );
      }
    }
    return result;
  }

  WBuilder buildDetail(
    LazyNotifier<ResponseConfig> sideConfig, {
    required VoidCallback onClose,
  }) {
    _commentRequester ??= GithubRequester.issueCommentRequester(issueUrl: url);
    return (BuildContext context) {
      final size = MediaQuery.of(context).size;
      return CustomScrollView(
        key: ValueKey('issue_${url}_$time'),  // 如果不传，会复用一些组件导致不刷新
        slivers: [
          SliverAppBar(
            title: LongPressCopyBubble(text: title),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            floating: true, // 向上滑动时立即出现
            snap: true, // 快速滑动时立即出现
            pinned: false, // 不固定在顶部
            // 展开/收起 按钮 仅仅在横屏时显示
            leading: (size.width < size.height)
                ? null
                : ValueListenableBuilder<ResponseConfig>(
                    valueListenable: sideConfig,
                    builder: (context, config, child) {
                      return IconButton(
                        icon: config.sideWidthRatio < 0.9
                            ? const Icon(Icons.arrow_back)
                            : const Icon(Icons.arrow_forward),
                        onPressed: () {
                          config.sideWidthRatio = config.sideWidthRatio < 0.9
                              ? 1.0
                              : 0.5;
                          sideConfig.notify();
                        },
                      );
                    },
                  ),
            actions: [
              IconButton(icon: const Icon(Icons.close), onPressed: onClose),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Theme.of(context).textTheme.bodySmall?.fontSize ?? 12.0,
                vertical: 0,
              ),
              child: Column(
                children: [
                  // 内容 不需要自带的scroll 会报错
                  MarkdownBlock(
                    data: raw,
                    selectable: true,
                    generator: mdHtmlSupport,
                    config: AppTheme.myMarkdownConfig,
                  ),
                  // 署名
                  if (user.isNotEmpty || time.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        [
                          if (user.isNotEmpty) 'by $user',
                          if (time.isNotEmpty) 'at $time',
                        ].join(' '),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  // 评论 用ValueListenableBuilder以保证可以自我刷新
                  ValueListenableBuilder<ResponseConfig>(
                    valueListenable: sideConfig,
                    builder: (context, config, child) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (comments.isNotEmpty)
                          Text(
                            'Comments',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (comments.isNotEmpty)
                          ...comments.map((e) => e.build(context)),
                        // 显示加载评论的按钮
                        if (_commentRequester!.hasNext)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Center(
                              child: _commentRequester!.isLoading
                                  ? CircularProgressIndicator()
                                  : ElevatedButton(
                                      onPressed: () async {
                                        _commentRequester!
                                            .fetchNext()
                                            .then((comments) {
                                              this.comments.addAll(comments);
                                              sideConfig.notify();
                                            })
                                            .catchError((e) {
                                              showError(e.toString());
                                            });
                                        sideConfig.notify();
                                      },
                                      child: Text('Load more comments'),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    };
  }
}

class IssueComment {
  final String user;
  final String time;
  final String raw;

  IssueComment({required this.user, required this.time, required this.raw});

  static List<IssueComment> parseGithub(List<dynamic> rawCommentList) {
    List<IssueComment> result = [];
    for (var comment in rawCommentList) {
      if (comment is Map<String, dynamic>) {
        result.add(
          IssueComment(
            user: comment['user']?['login'] ?? '',
            time: comment['created_at'] ?? '',
            raw: comment['body'] ?? '',
          ),
        );
      }
    }
    return result;
  }

  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$user:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                time,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
          MarkdownBlock(data: raw, selectable: true, generator: mdHtmlSupport, config: AppTheme.myMarkdownConfig),
          const Divider(),
        ],
      ),
    );
  }
}
