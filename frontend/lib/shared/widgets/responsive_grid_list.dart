import 'package:flutter/material.dart';

class ResponsiveGridList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;

  final bool scrollable;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveGridList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minItemWidth = 600,
    this.spacing = 16,
    this.runSpacing = 16,
    this.padding = const EdgeInsets.all(16),
    this.scrollable = true,
    this.shrinkWrap = false,
    this.physics = const AlwaysScrollableScrollPhysics(),
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = (constraints.maxWidth / minItemWidth).floor();
        if (crossAxisCount < 1) crossAxisCount = 1;

        // Group items into rows
        final rows = <Widget>[];
        for (var i = 0; i < itemCount; i += crossAxisCount) {
          final rowChildren = <Widget>[];
          for (var j = 0; j < crossAxisCount; j++) {
            final itemIndex = i + j;
            if (itemIndex < itemCount) {
              rowChildren.add(
                Expanded(
                  child: itemBuilder(context, itemIndex),
                ),
              );
            } else {
              // Add an empty expanded widget to keep sizes consistent for the last row
              rowChildren.add(const Expanded(child: SizedBox.shrink()));
            }

            // Add spacing between items in a row
            if (j < crossAxisCount - 1) {
              rowChildren.add(SizedBox(width: spacing));
            }
          }

          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowChildren,
            ),
          );

          // Add spacing between rows
          if (i + crossAxisCount < itemCount) {
            rows.add(SizedBox(height: runSpacing));
          }
        }

        final col = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );

        if (!scrollable) {
          return Padding(padding: padding, child: col);
        }

        return SingleChildScrollView(
          physics: physics,
          padding: padding,
          child: col,
        );
      },
    );
  }
}
