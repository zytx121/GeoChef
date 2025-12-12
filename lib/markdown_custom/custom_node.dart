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


/// 识别 <div ...>...</div> 块的 BlockSyntax
class DivBlockSyntax extends m.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^(\s*)<div(\s+[^>]*)?>\s*$');
  
  static final _endPattern = RegExp(r'^\s*</div>\s*$');

  @override
  m.Node parse(m.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content)!;
    
    // 解析属性
    final attributes = <String, String>{};
    final attrString = match.group(2);
    if (attrString != null) {
      final attrRegex = RegExp(r'([a-zA-Z0-9-]+)="([^"]*)"');
      for (final m in attrRegex.allMatches(attrString)) {
        attributes[m.group(1)!] = m.group(2)!;
      }
    }

    final childLines = <String>[];
    int openDivs = 1;

    parser.advance(); // 跳过起始<div>

    while (!parser.isDone) {
      final line = parser.current.content;
      if (pattern.hasMatch(line)) {
        openDivs++;
      } else if (_endPattern.hasMatch(line)) {
        openDivs--;
        if (openDivs == 0) {
          parser.advance(); // 跳过最后一个</div>
          break;
        }
      }
      childLines.add(line);
      parser.advance();
    }

    // 计算最小缩进
    int? commonIndent;
    for (var line in childLines) {
      if (line.trim().isEmpty) continue;
      final indent = line.indexOf(line.trim());
      if (commonIndent == null || indent < commonIndent) {
        commonIndent = indent;
      }
    }
    commonIndent ??= 0;

    // 去除缩进
    final dedentedLines = childLines.map((line) {
      if (line.trim().isEmpty) return '';
      if (line.length >= commonIndent! && line.substring(0, commonIndent).trim().isEmpty) {
        return line.substring(commonIndent);
      }
      return line.trimLeft();
    }).toList();

    // 递归解析div内部内容为markdown节点（block级）
    final childNodes = parser.document.parseLines(dedentedLines);
    
    _cleanupWhitespace(childNodes);

    final element = m.Element('div', childNodes);
    element.attributes.addAll(attributes);
    return element;
  }

  void _cleanupWhitespace(List<m.Node> nodes) {
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is m.Element) {
        if (node.tag == 'code' || node.tag == 'pre') continue;
        if (node.children != null) {
          _cleanupWhitespace(node.children!);
        }
      } else if (node is m.Text) {
        final newText = node.text.replaceAll(RegExp(r'\s+'), ' ');
        nodes[i] = m.Text(newText);
      }
    }
  }
}

class DivNode extends ElementNode {
  final Map<String, String> attributes;
  final MarkdownConfig config;
  final WidgetVisitor visitor;

  DivNode(this.attributes, this.config, this.visitor);

  @override
  InlineSpan build() {
    return WidgetSpan(
      child: SizedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: _getCrossAlignment(attributes['align']),
          children: children.map((child) {
            return Text.rich(
              child.build(),
              textAlign: _getTextAlign(attributes['align']),
            );
          }).toList(),
        ),
      ),
    );
  }

  CrossAxisAlignment _getCrossAlignment(String? align) {
    switch (align) {
      case 'center': return CrossAxisAlignment.center;
      case 'right': return CrossAxisAlignment.end;
      case 'left': return CrossAxisAlignment.start;
      default: return CrossAxisAlignment.start;
    }
  }

  TextAlign? _getTextAlign(String? align) {
    switch (align) {
      case 'center': return TextAlign.center;
      case 'right': return TextAlign.right;
      case 'left': return TextAlign.left;
      default: return null;
    }
  }
}

final divGenerator = SpanNodeGeneratorWithTag(
  tag: 'div',
  generator: (node, config, visitor) => DivNode(node.attributes, config, visitor)
  // 已经在DivBlockSyntax中accept(即加入children)了，无需再加
);