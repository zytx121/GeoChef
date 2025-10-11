import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

class VisitMap extends StatefulWidget {
  final String src;
  const VisitMap({super.key, required this.src});

  @override
  State<VisitMap> createState() => _VisitMapState();
}

class _VisitMapState extends State<VisitMap> {
  late final String _viewType;
  @override
  void initState() {
    super.initState();
    if (kIsWeb == false) {
      throw UnsupportedError('VisitMap is only supported on web platform');
    }
    _viewType = "visit_map_${DateTime.now().millisecondsSinceEpoch}";
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final div = web.HTMLDivElement();

      final script = web.HTMLScriptElement();
      script.type = 'text/javascript';
      script.id = 'clstr_globe';
      script.src =
          '//clustrmaps.com/globe.js?d=aTs2G96jVg3OE7Fi4QsvOITD0NJ63gc2c6HSkUFpnW0';

      div.append(script);
      return div;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
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
