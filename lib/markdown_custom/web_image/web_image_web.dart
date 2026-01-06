import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

// 点击放大要搭配 web/index.html 中的 showImageOverlay 方法使用
@JS()
external void showImageOverlay(String id);

/// 用html渲染图片，支持跨域
/// 仅支持web平台
class WebImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final double? maxWidth;
  final void Function()? onTap; // 由于HtmlElementView不能响应点击，所以需要一个透明的手势层
  final bool allowClickToEnlarge;

  const WebImage({
    super.key,
    this.url = '',
    this.width,
    this.height,
    this.maxWidth,
    this.onTap,
    this.allowClickToEnlarge = true,
  });

  @override
  State<WebImage> createState() => _WebImageState();
}

class _WebImageState extends State<WebImage> {
  double? _naturalWidth;
  double? _naturalHeight;
  late String _viewType;

  @override
  void initState() {
    super.initState();
    if (kIsWeb == false) {
      throw UnsupportedError('WebImage is only supported on web platform');
    }
    _viewType =
        "web_image_${widget.url.hashCode}_${DateTime.now().millisecondsSinceEpoch}";

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final img = web.HTMLImageElement();
      img.id = _viewType;
      img.src = widget.url;
      img.style
        ..maxWidth = '100%'
        ..maxHeight = '100%'
        ..display = 'block'
        ..marginLeft = 'auto'
        ..marginRight = 'auto'
        ..pointerEvents = 'none';
      // 不能用js的onclick，不然会穿透flutter的元素响应点击
      img.onLoad.listen((_) {
        if (!mounted) return;
        if (_naturalWidth == null) {
          setState(() {
            _naturalWidth = img.naturalWidth.toDouble();
            _naturalHeight = img.naturalHeight.toDouble();
          });
        }
      });

      return img;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb == false) {
      throw UnsupportedError('WebImage is only supported on web platform');
    }
    // 逻辑：
    // 1. 如果用户传了 width/height，优先使用。
    // 2. 如果没传，等 onLoad 获取 naturalSize。
    // 3. 在此基础上，如果宽度 > maxWidth，则按比例缩小。

    double? displayWidth = widget.width ?? _naturalWidth;
    double? displayHeight = widget.height ?? _naturalHeight;

    // 处理自适应缩放逻辑
    if (displayWidth != null && displayHeight != null) {
      double effectiveMaxWidth = widget.maxWidth ?? double.infinity;

      if (displayWidth > effectiveMaxWidth) {
        double ratio = effectiveMaxWidth / displayWidth;
        displayWidth = effectiveMaxWidth;
        displayHeight = displayHeight * ratio;
      }
    }

    // 在图片尺寸未获取到之前，给一个极小的占位或透明容器
    // 避免初次渲染时 img 以原始超大尺寸闪现
    return SizedBox(
      width: displayWidth ?? 1,
      height: displayHeight ?? 1,
      child: Stack(
        // 放一个透明的手势层在上面，防止穿透
        children: [
          // HtmlElementView 即使有遮罩、遮罩没有onTap，也无法响应父元素的点击事件
          HtmlElementView(key: ValueKey(_viewType), viewType: _viewType),
          Positioned.fill(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  if (widget.allowClickToEnlarge) {
                    showImageOverlay(_viewType);
                  }
                  widget.onTap?.call();
                },
                onLongPress: () => showImageOverlay(_viewType),
                behavior: HitTestBehavior.translucent,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
