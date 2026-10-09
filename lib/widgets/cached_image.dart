import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'skeletons.dart';

class CachedAvatar extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;
  const CachedAvatar({super.key, this.url, this.size = 48, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return SkeletonCircle(size: size);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai$url',
        width: size, height: size, fit: BoxFit.cover,
        placeholder: (_, __) => const SkeletonCircle(),
        errorWidget: (_, __, ___) => Container(width: size, height: size, color: Colors.grey[200], child: const Icon(Icons.person, color: Colors.grey)),
      ),
    );
  }
}