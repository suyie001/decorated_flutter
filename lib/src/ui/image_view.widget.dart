import 'dart:async';

import 'package:decorated_flutter/decorated_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_networkimage/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ImageView extends StatelessWidget {
  ImageView.assetImage(
    this.imagePath, {
    this.width,
    this.height,
    this.size,
    this.fit = BoxFit.contain,
    this.color,
  })  : imageUrl = null,
        svgPath = null,
        svgUrl = null,
        icon = null,
        imageUrlFuture = null,
        svgUrlFuture = null,
        useDiskCache = true;

  ImageView.networkImage(
    this.imageUrl, {
    this.width,
    this.height,
    this.size,
    this.fit = BoxFit.contain,
    this.color,
    this.useDiskCache = true,
  })  : imagePath = null,
        svgUrl = null,
        icon = null,
        imageUrlFuture = null,
        svgUrlFuture = null,
        svgPath = null;

  ImageView.futureImage(
    this.imageUrlFuture, {
    this.width,
    this.height,
    this.size,
    this.fit = BoxFit.contain,
    this.color,
    this.useDiskCache = true,
  })  : imagePath = null,
        svgUrl = null,
        icon = null,
        imageUrl = null,
        svgUrlFuture = null,
        svgPath = null;

  ImageView.assetSvg(
    this.svgPath, {
    this.width,
    this.height,
    this.size,
    this.fit = BoxFit.contain,
    this.color,
  })  : imageUrl = null,
        imagePath = null,
        svgUrl = null,
        icon = null,
        imageUrlFuture = null,
        svgUrlFuture = null,
        useDiskCache = true;

  ImageView.networkSvg(
    this.svgUrl, {
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.size,
    this.color,
    this.useDiskCache = true,
  })  : imageUrl = null,
        imagePath = null,
        icon = null,
        imageUrlFuture = null,
        svgUrlFuture = null,
        svgPath = null;

  ImageView.futureSvg(
    this.svgUrlFuture, {
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.size,
    this.color,
    this.useDiskCache = true,
  })  : imageUrl = null,
        imagePath = null,
        svgUrl = null,
        icon = null,
        imageUrlFuture = null,
        svgPath = null;

  ImageView.icon(
    this.icon, {
    this.size,
    this.color,
  })  : imageUrl = null,
        imagePath = null,
        svgPath = null,
        svgUrl = null,
        width = null,
        height = null,
        fit = null,
        imageUrlFuture = null,
        svgUrlFuture = null,
        useDiskCache = null;

  /// 本地图片路径
  final String imagePath;

  /// 图片url
  final String imageUrl;

  /// 本地svg路径
  final String svgPath;

  /// svg的url
  final String svgUrl;

  /// 宽度 如果同时设置了[width], [height]和[size], 那么优先[size]
  final double width;

  /// 高度 如果同时设置了[width], [height]和[size], 那么优先[size]
  final double height;

  /// 适应模式
  final BoxFit fit;

  /// 颜色
  final Color color;

  /// 是否使用硬盘缓存
  final bool useDiskCache;

  /// icon
  final IconData icon;

  /// 大小, 如果同时设置了[width], [height]和[size], 那么优先[size]
  final double size;

  /// 需要异步获取的图片url
  final Future<String> imageUrlFuture;

  /// 需要异步获取的svg url
  final Future<String> svgUrlFuture;

  @override
  Widget build(BuildContext context) {
    if (imagePath != null) {
      return Image.asset(
        imagePath,
        width: size ?? width,
        height: size ?? height,
        fit: fit,
        color: color,
      );
    } else if (imageUrl != null) {
      return Image(
        image: AdvancedNetworkImage(imageUrl, useDiskCache: useDiskCache),
        width: size ?? width,
        height: size ?? height,
        fit: fit,
        color: color,
      );
    } else if (svgPath != null) {
      return SvgPicture.asset(
        svgPath,
        width: size ?? width,
        height: size ?? height,
        fit: fit,
        color: color,
      );
    } else if (svgUrl != null) {
      return SvgPicture.network(
        svgUrl,
        width: size ?? width,
        height: size ?? height,
        fit: fit,
        color: color,
      );
    } else if (imageUrlFuture != null) {
      return PreferredFutureBuilder<String>(
        future: imageUrlFuture,
        showLoading: false,
        builder: (data) {
          return ImageView.networkImage(
            data,
            width: size ?? width,
            height: size ?? height,
            fit: fit,
            color: color,
            useDiskCache: useDiskCache,
          );
        },
      );
    } else if (svgUrlFuture != null) {
      return PreferredFutureBuilder<String>(
        future: svgUrlFuture,
        showLoading: false,
        builder: (data) {
          return ImageView.networkSvg(
            data,
            width: size ?? width,
            height: size ?? height,
            fit: fit,
            color: color,
          );
        },
      );
    } else if (icon != null) {
      return Icon(icon, size: size, color: color);
    } else {
      // 如果图片地址为null的话, 那就不显示
      return SizedBox.shrink();
    }
  }
}
