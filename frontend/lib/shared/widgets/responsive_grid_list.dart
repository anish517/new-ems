import 'package:flutter/material.dart';

/// A fluid, responsive grid list that automatically calculates optimal column counts
/// based on available width while maintaining balanced item proportions.
class ResponsiveGridList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double minItemWidth;
  final int? maxCrossAxisCount;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;

  final bool scrollable;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  const ResponsiveGridList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minItemWidth = 280,
    this.maxCrossAxisCount,
    this.spacing = 16,
    this.runSpacing = 16,
    this.padding = const EdgeInsets.all(16),
    this.scrollable = true,
    this.shrinkWrap = false,
    this.physics = const AlwaysScrollableScrollPhysics(),
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - padding.horizontal;
        int crossAxisCount = (availableWidth / minItemWidth).floor();
        if (crossAxisCount < 1) crossAxisCount = 1;
        if (maxCrossAxisCount != null && crossAxisCount > maxCrossAxisCount!) {
          crossAxisCount = maxCrossAxisCount!;
        }

        // Group items into responsive rows
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
              // Add an empty expanded widget to keep grid sizing balanced on the final row
              rowChildren.add(const Expanded(child: SizedBox.shrink()));
            }

            // Spacing between columns in a row
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

          // Spacing between rows
          if (i + crossAxisCount < itemCount) {
            rows.add(SizedBox(height: runSpacing));
          }
        }

        final col = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
          children: rows,
        );

        if (!scrollable) {
          return Padding(padding: padding, child: col);
        }

        return SingleChildScrollView(
          controller: controller,
          physics: physics,
          padding: padding,
          child: col,
        );
      },
    );
  }
}

/// Sliver variant of [ResponsiveGridList] for seamless integration in [CustomScrollView]
class SliverResponsiveGridList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double minItemWidth;
  final int? maxCrossAxisCount;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;

  const SliverResponsiveGridList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minItemWidth = 280,
    this.maxCrossAxisCount,
    this.spacing = 16,
    this.runSpacing = 16,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: padding,
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.crossAxisExtent;
          int crossAxisCount = (availableWidth / minItemWidth).floor();
          if (crossAxisCount < 1) crossAxisCount = 1;
          if (maxCrossAxisCount != null && crossAxisCount > maxCrossAxisCount!) {
            crossAxisCount = maxCrossAxisCount!;
          }

          final rowCount = (itemCount / crossAxisCount).ceil();

          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, rowIndex) {
                final startIndex = rowIndex * crossAxisCount;
                final rowChildren = <Widget>[];

                for (var j = 0; j < crossAxisCount; j++) {
                  final itemIndex = startIndex + j;
                  if (itemIndex < itemCount) {
                    rowChildren.add(
                      Expanded(
                        child: itemBuilder(context, itemIndex),
                      ),
                    );
                  } else {
                    rowChildren.add(const Expanded(child: SizedBox.shrink()));
                  }

                  if (j < crossAxisCount - 1) {
                    rowChildren.add(SizedBox(width: spacing));
                  }
                }

                return Padding(
                  padding: EdgeInsets.only(bottom: rowIndex < rowCount - 1 ? runSpacing : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rowChildren,
                  ),
                );
              },
              childCount: rowCount,
            ),
          );
        },
      ),
    );
  }
}
