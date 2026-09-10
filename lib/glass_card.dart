// Visual dos cards usados no app: um fundo levemente transparente

import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final bool isDark;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;

  const GlassCard({
    super.key,
    required this.child,
    required this.isDark,
    this.borderRadius = 10.0,
    this.padding,
    this.margin,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        // 1. Fundo gradiente translúcido (simula a luz passando pelo vidro).
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.02),
                ]
              : [
                  Colors.white.withValues(alpha: 0.25),
                  Colors.white.withValues(alpha: 0.05),
                ],
        ),
        // 2. Borda branca nítida (reflexo da aresta do vidro).
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.5),
          width: 1.2,
        ),
        // 3. Sombra externa suave, só para descolar do fundo.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}
