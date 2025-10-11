import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

// clustrmaps 提供的js脚本用了 $(window).load 这种写法，导致后续插入不被触发
// 所以本类依赖 web/index.html 中处理 window.onload 的脚本
class VisitMap extends StatefulWidget {
  final String src; // 特指`//clustrmaps.com/globe.js?d=`开头的
  final String id;  // 保持clustrmaps的id参数一致
  const VisitMap({super.key, required this.src, required this.id});

  @override
  State<VisitMap> createState() => _VisitMapState();
}

class _VisitMapState extends State<VisitMap> {
  late final String _viewType;
  double? initWidth;
  late final String divId;
  @override
  void initState() {
    super.initState();
    if (kIsWeb == false) {
      throw UnsupportedError('VisitMap is only supported on web platform');
    }
    _viewType = "visit_map_${DateTime.now().millisecondsSinceEpoch}";
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final div = web.HTMLDivElement();
      div.id = divId = 'clustrmaps_${widget.id.hashCode}';
      div.style
        ..width = '100%'
        ..height = '100%'
        ..transformOrigin = '0 0'
        ..transform = 'scale(1, 1)';

      final script = web.HTMLScriptElement();
      script.type = 'text/javascript';
      script.id = widget.id;
      script.src = widget.src;

      div.append(script);
      return div;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
        initWidth ??= width;
        if (width != initWidth!) {
          // 由于clustrmaps提供的视图是固定大小的svg，不能自适应宽度 所以用css强制缩放
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            final div = web.document.getElementById(divId) as web.HTMLDivElement?;
            if (div != null) {
              div.style.transform = 'scale(${width / initWidth!}, ${width / initWidth!})';
            }
          });
        }
        if (width.isInfinite || width == 0) {
          width = MediaQuery.of(context).size.width;
        }
        final height = width / 2;
        return Center(
          child: SizedBox(
            width: height,
            height: height,
            child: HtmlElementView(
              key: ValueKey(_viewType),
              viewType: _viewType
            ),
          ),
        );
      },
    );
  }
}
