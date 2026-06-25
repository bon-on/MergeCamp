import 'package:flutter/material.dart';

class AdBanner extends StatelessWidget {
  const AdBanner({super.key, required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
