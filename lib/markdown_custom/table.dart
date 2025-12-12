import 'package:flutter/material.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/blocks/container/table.dart';
import 'more_img.dart';
import 'package:markdown_widget/widget/widget_visitor.dart';

final tableGenerator = SpanNodeGeneratorWithTag(
  tag: MarkdownTag.table.name,
  generator: (e, config, visitor) => _TableNode(),
);

class _TableNode extends TableNode {
  _TableNode() : super(MarkdownConfig.defaultConfig);
  @override
  InlineSpan build() {
    recursivelySetSvgNodeInTable(this);
    return super.build();
  }
}