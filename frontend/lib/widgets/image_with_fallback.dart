import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ImageWithFallback extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? semanticsLabel;

  const ImageWithFallback({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: semanticsLabel,
      errorBuilder: (context, error, stackTrace) {
        // 에러 발생 시 로컬 SVG 에셋을 보여줌
        return Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: Center(
            child: SvgPicture.asset(
              'assets/images/fallback_image.svg',
              width: (width ?? 100) * 0.5,
              height: (height ?? 100) * 0.5,
              colorFilter: ColorFilter.mode(
                Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.3),
                BlendMode.srcIn,
              ),
            ),
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
    );
  }
}