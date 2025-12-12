import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:flutter/foundation.dart';
import 'web_image/web_image.dart';

final moreImgGenerator = SpanNodeGeneratorWithTag(
  tag: 'img',
  generator: (node, config, visitor) {
    final attr = node.attributes;
    final src = attr['src'] ?? '';

    // 如果没有跨域或http问题，可以注释下一行
    if (kIsWeb == true) return SvgNode(attr, config, visitor);

    if (src.toLowerCase().contains('.svg')) {
      // 不一定在末尾
      return SvgNode(attr, config, visitor);
    }
    return ImageNode(attr, config, visitor);
  },
);

/// 不仅支持SVG，在web还能用img标签，使得图片可以跨域
class SvgNode extends ImageNode {
  bool clickToEnlarge;
  VoidCallback? onTap;
  SvgNode(
    super.attributes,
    super.config,
    super.visitor, {
    this.clickToEnlarge = true,
    this.onTap,
  });

  @override
  InlineSpan build() {
    double? width;
    double? height;
    if (attributes['width'] != null && attributes['width']!.isNotEmpty) {
      width = double.tryParse(attributes['width']!);
    }
    if (attributes['height'] != null && attributes['height']!.isNotEmpty) {
      height = double.tryParse(attributes['height']!);
    }
    final imageUrl = attributes['src'] ?? '';
    late final Widget result;
    // 如果是web平台，使用WebImage获取完全的兼容和跨域支持
    if (kIsWeb == true) {
      if (attributes['inTable'] == '1') {
        // table内的图片不能用layoutbuilder，必须给定最大宽度
        result = WebImage(
          url: imageUrl,
          width: width,
          height: height,
          allowClickToEnlarge: clickToEnlarge,
          maxWidth: 1024,
          onTap: onTap,
        );
      } else {
        result = LayoutBuilder(
          builder: (context, constraints) {
            return WebImage(
              url: imageUrl,
              width: width,
              height: height,
              allowClickToEnlarge: clickToEnlarge,
              maxWidth: constraints.maxWidth,
              onTap: onTap,
            );
          },
        );
      }
    } else {
      // SVG会显示异常 疑似是插件的问题
      final temp = SvgPicture.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.contain,
        clipBehavior: Clip.none,
        placeholderBuilder: (BuildContext context) =>
            buildErrorImage(imageUrl, attributes['alt'] ?? '', null),
      );
      // 点击放大
      result = Builder(
        builder: (context) {
          return InkWell(
            child: Hero(tag: result.hashCode, child: temp),
            onTap: () {
              if (clickToEnlarge) _showImage(context, temp);
              onTap?.call();
            },
          );
        },
      );
    }
    return WidgetSpan(child: result);
  }

  /// show image in a new window
  void _showImage(BuildContext context, Widget child) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, _, _) => ImageViewer(child: child),
      ),
    );
  }
}

void recursivelySetSvgNodeInTable(SpanNode node) {
  if (node is SvgNode) {
    node.attributes['inTable'] = '1';
  } else if (node is ElementNode) {
    for (final child in node.children) {
      recursivelySetSvgNodeInTable(child);
    }
  }
}