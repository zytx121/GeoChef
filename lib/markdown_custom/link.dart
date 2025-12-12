import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/widget/widget_visitor.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/span_node.dart';
import 'package:markdown_widget/widget/blocks/leaf/link.dart';
import 'more_img.dart';

final linkGenerator = SpanNodeGeneratorWithTag(
  tag: MarkdownTag.a.name,
  generator: (e, config, visitor) => _LinkNode(e.attributes, config.a),
);

// 定制LinkNode，使其支持SvgNode，因为SvgNode可能会使用WebImage，其中的HtmlElementView会影响父组件的点击事件响应
class _LinkNode extends LinkNode {
  _LinkNode(super.attributes, super.linkConfig);

  InlineSpan _buildChild(SpanNode child, String url) {
    if (child is SvgNode) {
      child.onTap = () => _onLinkTap(linkConfig, url);
      child.clickToEnlarge = false;
      return child.build();
    } else if (child is _LinkNode) {
      return child.build();
    } else {
      return _toLinkInlineSpan(
        child.build(),
        () => _onLinkTap(linkConfig, url),
      );
    }
  }

  @override
  InlineSpan build() {
    final url = attributes['href'] ?? '';
    return TextSpan(
      children: [
        for (final child in children) _buildChild(child, url),
        if (children.isNotEmpty)
          // FIXME: this is a workaround, maybe need fixed by flutter framework.
          // add a space to avoid the space area of line end can be tapped.
          TextSpan(text: ' '),
      ],
    );
  }

  void _onLinkTap(LinkConfig linkConfig, String url) {
    if (linkConfig.onTap != null) {
      linkConfig.onTap?.call(url);
    } else {
      launchUrl(Uri.parse(url));
    }
  }

  @override
  TextStyle get style =>
      parentStyle?.merge(linkConfig.style) ?? linkConfig.style;
}

// add a tap gesture recognizer to the span.
InlineSpan _toLinkInlineSpan(InlineSpan span, VoidCallback onTap) {
  if (span is TextSpan) {
    span = TextSpan(
      text: span.text,
      children: span.children?.map((e) => _toLinkInlineSpan(e, onTap)).toList(),
      style: span.style,
      recognizer: TapGestureRecognizer()..onTap = onTap,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      spellOut: span.spellOut,
    );
  } else if (span is WidgetSpan) {
    span = WidgetSpan(
      child: InkWell(child: span.child, onTap: onTap),
      alignment: span.alignment,
      baseline: span.baseline,
      style: span.style,
    );
  }
  return span;
}
