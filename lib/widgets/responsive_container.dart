import 'package:flutter/material.dart';

/// Widget helper para responsividade desktop/mobile
/// Limita a largura de formulários e inputs em telas grandes
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    Key? key,
    required this.child,
    this.maxWidth = 600, // Largura máxima padrão para desktop
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Extensão para facilitar o uso de responsividade
extension ResponsiveWidget on Widget {
  /// Limita a largura do widget em telas grandes (desktop)
  Widget maxWidth(double width) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > width) {
          return Center(
            child: SizedBox(
              width: width,
              child: this,
            ),
          );
        }
        return this;
      },
    );
  }

  /// Adiciona padding responsivo (maior em desktop)
  Widget responsivePadding(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    return Padding(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: this,
    );
  }
}

/// Helper para detectar plataforma
class ResponsiveHelper {
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width > 600;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width <= 600;
  }

  /// Retorna largura máxima ideal para formulários
  static double getFormMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 600; // Desktop grande
    if (width > 600) return 500; // Tablet/Desktop pequeno
    return width; // Mobile - usa largura total
  }

  /// Retorna padding responsivo
  static EdgeInsets getResponsivePadding(BuildContext context) {
    return EdgeInsets.all(isDesktop(context) ? 24.0 : 16.0);
  }

  /// Retorna espaçamento entre elementos
  static double getSpacing(BuildContext context) {
    return isDesktop(context) ? 20.0 : 16.0;
  }
}
