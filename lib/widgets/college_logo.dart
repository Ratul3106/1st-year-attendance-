import 'package:flutter/material.dart';

/// Clean and compact college logo widget for Vel Tech High Tech
class CollegeLogo extends StatelessWidget {
  final double height;
  final double? width;
  final BoxFit fit;

  const CollegeLogo({
    super.key,
    this.height = 34,
    this.width,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: height),
      child: Image.asset(
        'assets/images/college_logo.png',
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.school,
                size: height * 0.8,
                color: const Color(0xFF1E40AF),
              ),
              const SizedBox(width: 6),
              const Text(
                "Vel Tech",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

