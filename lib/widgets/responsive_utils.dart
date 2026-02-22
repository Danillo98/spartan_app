import 'package:flutter/material.dart';

/// Um container inteligente que limita a largura do conteúdo em telas grandes.
/// Ideal para Web/Desktop para evitar que botões e cards fiquem esticados demais.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200.0, // Largura máxima do conteúdo no PC
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(0),
          child: child,
        ),
      ),
    );
  }
}

/// Um Grid que se adapta:
/// - 1 coluna no Celular
/// - 2 colunas no Tablet
/// - 3 colunas no PC (opcional)
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16.0,
    this.runSpacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 2; // Padrão: 2 colunas (Celular)

    if (width > 800) {
      crossAxisCount = 5; // PC / Tablet
    }

    // A lógica de reduzir colunas se tiver poucos itens foi removida
    // para manter o tamanho dos cards consistente (quadrados/retangulares)
    // independentemente da quantidade de itens.

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
        childAspectRatio: 1.3, // Cards um pouco mais retangulares
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}
