import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:material_charts/material_charts.dart';
import 'package:flutter/material.dart';
import 'package:geochef/github_request.dart';
import '../lazy_notifier.dart';
import '../common.dart';
import '../config.dart';
import '../theme.dart';
import './visit_map/visit_map.dart';

/// issue统计概览页面 侧边栏可自定义
/// 需要搭配 https://github.com/zytx121/issueStats 使用
class OverviewPage extends StatefulWidget implements SubPageWidget {
  @override
  final LazyNotifier<ResponseConfig> sideConfig;

  @override
  final int index;

  @override
  final LazyNotifier<int> pageIndex;

  /// 必须自定义侧边栏
  final WBuilder sideBuilder;
  final String owner;
  final String repo;

  const OverviewPage({
    super.key,
    this.owner = Config.owner,
    this.repo = Config.repo,
    required this.sideConfig,
    required this.pageIndex,
    this.index = 0,
    required this.sideBuilder,
  });
  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DashboardStat? stat;
  Future<Null>? inited;

  @override
  void initState() {
    super.initState();
    widget.pageIndex.addListener(() {
      if (widget.pageIndex.value != widget.index) return;
      // 当前轮到自己了
      inited ??= _init(); // 懒初始化
      widget.sideConfig.value.sideBuilder = widget.sideBuilder;
      widget.sideConfig.notify();
    });
  }

  Future<Null> _init() {
    return getDashboardStat(widget.owner, widget.repo)
        .then((s) {
          setState(() {
            stat = s;
          });
        })
        .catchError((e) {
          showError(e.toString());
        });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (stat == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          Image.asset(
            'assets/bg.png',
            width: MediaQuery.of(context).size.width,
            fit: BoxFit.cover,
          ),
          Padding(
            padding: EdgeInsets.all(
              Theme.of(context).textTheme.titleMedium?.fontSize ?? 17.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest Additions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical:
                        Theme.of(context).textTheme.titleMedium?.fontSize ?? 17,
                  ),
                  child: _buildLastCreated(context),
                ),
                _buildTopLabels(context),
                SizedBox(
                  height: Theme.of(context).textTheme.titleLarge?.fontSize,
                ),
                Text(
                  'Label Distribution',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                _buildLabelDistributionChart(context),
                if (kIsWeb == true)
                  Text(
                    'Visitor Map',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                _buildVisitMap(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastCreated(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.book,
            iconColor: Colors.blue,
            title: 'Last 7 Days',
            value: stat!.createdInPastDays(7).toString(),
            valueColor: Colors.blue,
            unit: 'new Issues',
            gradientColors: [
              const Color(0xFFF3F8FF),
              const Color.fromARGB(255, 202, 223, 255),
            ],
          ),
        ),
        SizedBox(
          width: Theme.of(context).textTheme.titleMedium?.fontSize ?? 17.0,
        ),
        Expanded(
          child: _StatCard(
            icon: Icons.storage,
            iconColor: Colors.green,
            title: 'Last 30 Days',
            value: stat!.createdInPastDays(30).toString(),
            valueColor: Colors.green,
            unit: 'new Issues',
            gradientColors: [
              const Color(0xFFF3FFF6),
              const Color.fromARGB(255, 202, 255, 223),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopLabels(BuildContext context) {
    const int topN = 5;
    final labelsList = stat!.labels.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top $topN Hot Fields',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          min(labelsList.length, topN),
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FB),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize:
                          Theme.of(context).textTheme.bodyMedium?.fontSize ??
                          18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    labelsList[i].key,
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.w600,
                      fontSize:
                          Theme.of(context).textTheme.bodyLarge?.fontSize ?? 18,
                    ),
                  ),
                ),
                Text(
                  labelsList[i].value.toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelDistributionChart(BuildContext context) {
    // 构造 PieChartData 列表
    final labelList = stat!.labels.entries.toList();

    // 生成和 labelList 长度一致的同一色系颜色
    final baseColor = AppTheme.themeColor;
    final int n = labelList.length;
    final defaultColors = List.generate(n, (i) {
      // 通过 HSL 亮度调整生成不同深浅的蓝色
      final hsl = HSLColor.fromColor(baseColor);
      final lightness = 0.35 + 0.5 * (i / (n == 1 ? 1 : n - 1)); // 0.35~0.85
      return hsl.withLightness(lightness.clamp(0.2, 0.9)).toColor();
    });

    final data = List.generate(
      labelList.length,
      (i) => PieChartData(
        value: labelList[i].value.toDouble(),
        label: labelList[i].key,
      ),
    );

    if (data.isEmpty) {
      return const Center(child: Text('暂无标签数据'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 考虑padding，用LayoutBuilder取最大宽度
        final double maxWidth = constraints.maxWidth;

        // 不显示legend，因为这个库不够完善
        // label向两侧，所以高度比宽度小
        final double chartWidth = maxWidth;
        final double chartHeight = chartWidth / 2.2;

        return MaterialPieChart(
          data: data,
          width: chartWidth,
          height: chartHeight,
          minSizePercent: 0.0,
          chartRadius: chartWidth * 0.125,
          style: PieChartStyle(
            defaultColors: defaultColors,
            backgroundColor: Colors.transparent,
            startAngle: -180.0,
            holeRadius: 0.0,
            animationDuration: const Duration(milliseconds: 1000),
            animationCurve: Curves.easeOutCubic,
            showLabels: true,
            showValues: true,
            labelOffset: 10.0,
            showLegend: false,
            legendPosition: PieChartLegendPosition.right,
            labelPosition: LabelPosition.outside,
            showConnectorLines: true,
            connectorLineColor: Colors.black54,
            connectorLineStrokeWidth: 1.0,
            chartAlignment: ChartAlignment.center,
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            valueStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          interactive: true,
          showLabelOnlyOnHover: false,
          padding: const EdgeInsets.all(0),
        );
      },
    );
  }

  Widget _buildVisitMap(BuildContext context) {
    if (kIsWeb == false) {
      return const SizedBox.shrink();
    }
    return VisitMap(
      src:
          '//clustrmaps.com/globe.js?d=aTs2G96jVg3OE7Fi4QsvOITD0NJ63gc2c6HSkUFpnW0',
      id: 'clstr_globe',
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final Color valueColor;
  final String unit;
  final List<Color> gradientColors;

  const _StatCard({
    // ignore: unused_element_parameter
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.valueColor,
    required this.unit,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        Theme.of(context).textTheme.titleLarge?.fontSize ?? 21.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(
          (Theme.of(context).textTheme.titleLarge?.fontSize ?? 21) / 1.3,
        ),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                  color: Colors.grey.withAlpha(25),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: iconColor,
                size: Theme.of(context).textTheme.headlineMedium?.fontSize,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1, // 只显示一行
                  overflow: TextOverflow.clip, // 超出部分用...显示
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).textTheme.bodyLarge?.fontSize),
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          Text(
            unit,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
