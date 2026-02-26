import 'package:flutter/material.dart';

class AdaptiveLayout extends StatelessWidget {
  final Widget sidebar;
  final Widget? detail;
  final Widget emptyDetail;
  final double breakpoint;

  const AdaptiveLayout({
    super.key,
    required this.sidebar,
    this.detail,
    this.emptyDetail = const Center(child: Text('Select a project')),
    this.breakpoint = 600,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > breakpoint;

        if (isWide) {
          return Row(
            children: [
              SizedBox(
                width: 300,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: sidebar,
                ),
              ),
              Expanded(
                child: detail ?? emptyDetail,
              ),
            ],
          );
        }

        // Narrow: show detail if selected, otherwise sidebar
        if (detail != null) {
          return detail!;
        }
        return sidebar;
      },
    );
  }
}
