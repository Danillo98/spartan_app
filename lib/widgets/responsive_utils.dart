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
    int crossAxisCount = 1;

    if (width > 1100) {
      crossAxisCount = 3; // PC Grande
    } else if (width > 700) {
      crossAxisCount = 2; // Tablet / PC Pequeno
    }

    // Se tiver poucos itens, não precisa criar colunas vazias
    if (children.length < crossAxisCount) {
      crossAxisCount = children.length > 0 ? children.length : 1;
    }

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
