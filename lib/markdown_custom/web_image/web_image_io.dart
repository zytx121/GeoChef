import 'package:flutter/material.dart';

/// 非web平台兜底实现，不允许使用
class WebImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final double? maxWidth;
  final void Function()? onTap;
  final bool allowClickToEnlarge;

  const WebImage({
    super.key,
    this.url = '',
    this.width,
    this.height,
    this.maxWidth,
    this.onTap,
    this.allowClickToEnlarge = false,
  });

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError('WebImage is only implemented for web platform.');
  }
}