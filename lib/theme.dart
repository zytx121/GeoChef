import 'dart:math';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

class AppTheme {
  AppTheme._();

  static const Color themeColor = Colors.lightBlueAccent;

  /// 静态全局主题
  static final ThemeData themeData = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.themeColor),
    useMaterial3: true,
  );

  /// 页面尺寸设计
  static const double maxPageWidth = 1440; // 显示内容的最大宽度
  static const double sideWPH = 0.4; // 侧边宽度和屏幕高度的比例
  static const double maxSideWidth = 400; // 侧边栏的最大宽度
  static const double minSideWidth = 295; // 侧边栏的最小宽度

  /// 自定义的 Markdown 响应式文字大小
  static MarkdownConfig myMarkdownConfig = MarkdownConfig.defaultConfig;

  static double _ratialCurve(double t) {
    const k = 0.4;
    double afterCurve = switch (t) {
      < 1 => t,
      _ => k * t + (1 - k),
    };
    return afterCurve.clamp(0.7, 1.2);
  }

  /// 响应式文字主题，根据屏幕宽度调整文字大小
  static TextTheme responsiveTextTheme(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final double s = min(min(AppTheme.maxPageWidth,size.width), size.height);
    final double screenScale = _ratialCurve(s / 375); // IPhone 8 宽度 375px
    final double textScale = screenScale;

    final base = Theme.of(context).textTheme;

    // 利用副作用修改默认的 MarkdownConfig 没用，得保存一个自己的
    AppTheme.myMarkdownConfig = MarkdownConfig.defaultConfig.copy(
      configs: [
        H1Config(
          style: const H1Config().style.copyWith(fontSize: 23 * textScale),
        ),
        H2Config(
          style: const H2Config().style.copyWith(fontSize: 21 * textScale),
        ),
        H3Config(
          style: const H3Config().style.copyWith(fontSize: 19 * textScale),
        ),
        H4Config(
          style: const H4Config().style.copyWith(fontSize: 17.5 * textScale),
        ),
        H5Config(
          style: const H5Config().style.copyWith(fontSize: 16 * textScale),
        ),
        H6Config(
          style: const H6Config().style.copyWith(fontSize: 15 * textScale),
        ),
        const PreConfig().copy(textStyle: TextStyle(fontSize: 14 * textScale)),
        // LinkConfig 没有 fontSize
        PConfig(
          textStyle: const PConfig().textStyle.copyWith(
            fontSize: 14 * textScale,
          ),
        ),
      ],
    );

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: base.displayLarge!.fontSize! * textScale,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: base.displayMedium!.fontSize! * textScale,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: base.displaySmall!.fontSize! * textScale,
      ),

      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: base.headlineLarge!.fontSize! * textScale,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        // fontSize: base.headlineMedium!.fontSize! * textScale,
        fontSize: 28 * textScale,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: base.headlineSmall!.fontSize! * textScale,
      ),

      titleLarge: base.titleLarge?.copyWith(
        // fontSize: base.titleLarge!.fontSize! * textScale,
        fontSize: 21 * textScale,
      ),
      titleMedium: base.titleMedium?.copyWith(
        // fontSize: base.titleMedium!.fontSize! * textScale,
        fontSize: 17 * textScale,
      ),
      titleSmall: base.titleSmall?.copyWith(
        // fontSize: base.titleSmall!.fontSize! * textScale,
        fontSize: 15 * textScale,
      ),

      bodyLarge: base.bodyLarge?.copyWith(
        // fontSize: base.bodyLarge!.fontSize! * textScale,
        fontSize: 16 * textScale,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        // fontSize: base.bodyMedium!.fontSize! * textScale,
        fontSize: 14 * textScale,
      ),
      bodySmall: base.bodySmall?.copyWith(
        // fontSize: base.bodySmall!.fontSize! * textScale,
        fontSize: 12 * textScale,
      ),

      labelLarge: base.labelLarge?.copyWith(
        // fontSize: base.labelLarge!.fontSize! * textScale,
        fontSize: 13 * textScale,
      ),
      labelMedium: base.labelMedium?.copyWith(
        // fontSize: base.labelMedium!.fontSize! * textScale,
        fontSize: 11 * textScale,
      ),
      labelSmall: base.labelSmall?.copyWith(
        // fontSize: base.labelSmall!.fontSize! * textScale,
        fontSize: 9 * textScale,
      ),
    );
  }
}
