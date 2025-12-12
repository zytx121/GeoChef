import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart';

import 'html_support.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart';
import 'web_image/web_image.dart';

// 处理html表格，对其中的图片进一步定制
class CustomTextNode extends ElementNode {
  final String text;
  final MarkdownConfig config;
  final WidgetVisitor visitor;
  bool isTable = false;

  CustomTextNode(this.text, this.config, this.visitor);

  @override
  InlineSpan build() {
    if (isTable) {
      // deal complex table tag with html core widget
      return WidgetSpan(
        child: HtmlWidget(
          text,
          customWidgetBuilder: (element) {
            if (element.localName == 'img') {
              final src = element.attributes['src'] ?? '';
              final width = double.tryParse(element.attributes['width'] ?? '');
              final height = double.tryParse(
                element.attributes['height'] ?? '',
              );
              if (kIsWeb == true) {
                return LayoutBuilder(
                  // 和markdown widget不同，HTML的表格允许使用layoutbuilder
                  builder: (context, constraints) {
                    return WebImage(
                      url: src,
                      width: width,
                      height: height,
                      allowClickToEnlarge: true,
                      maxWidth: constraints.maxWidth,
                    );
                  },
                );
              }
              if (src.toLowerCase().contains('.svg')) {
                return SvgPicture.network(
                  src,
                  width: width,
                  height: height,
                  fit: BoxFit.contain,
                  clipBehavior: Clip.none,
                  placeholderBuilder: (BuildContext context) => SizedBox(
                    width: width,
                    height: height,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                );
              }
            }
            return null; // 使用默认
          },
        ),
      );
    }
    return super.build();
  }

  @override
  void onAccepted(SpanNode parent) {
    final textStyle = config.p.textStyle.merge(parentStyle);
    children.clear();
    if (!text.contains(htmlRep)) {
      accept(TextNode(text: text, style: textStyle));
      return;
    }
    //Intercept as table tag
    if (text.contains(tableRep)) {
      isTable = true;
      accept(parent);
      return;
    }

    //The remaining ones are processed by the regular HTML processing.
    final spans = parseHtml(
      m.Text(text),
      visitor: WidgetVisitor(
        config: visitor.config,
        generators: visitor.generators,
        richTextBuilder: visitor.richTextBuilder,
      ),
      parentStyle: parentStyle,
    );
    for (var element in spans) {
      isTable = false;
      accept(element);
    }
  }
}