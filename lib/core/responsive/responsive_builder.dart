import 'package:flutter/material.dart';
import 'responsive_service.dart';

/// Widget qui construit différents layouts selon le type d'appareil
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) mobile;
  final Widget Function(BuildContext context)? tablet;
  final Widget Function(BuildContext context)? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType = ResponsiveService.getDeviceType(constraints.maxWidth);
        switch (deviceType) {
          case DeviceType.desktop:
            return (desktop ?? tablet ?? mobile)(context);
          case DeviceType.tablet:
            return (tablet ?? mobile)(context);
          case DeviceType.mobile:
            return mobile(context);
        }
      },
    );
  }
}

/// Layout adaptatif avec navigation latérale pour tablettes
class AdaptiveLayout extends StatelessWidget {
  final Widget body;
  final Widget? sidePanel;
  final double sidePanelWidth;
  final bool showSidePanelOnTablet;

  const AdaptiveLayout({
    super.key,
    required this.body,
    this.sidePanel,
    this.sidePanelWidth = 320,
    this.showSidePanelOnTablet = true,
  });

  @override
  Widget build(BuildContext context) {
    if (sidePanel == null) return body;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLarge = constraints.maxWidth >= ResponsiveService.mobileMaxWidth;
        final showPanel = isLarge && showSidePanelOnTablet;

        if (!showPanel) return body;

        return Row(
          children: [
            SizedBox(width: sidePanelWidth, child: sidePanel),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

/// Grille responsive qui ajuste le nombre de colonnes
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType = ResponsiveService.getDeviceType(constraints.maxWidth);
        int columns;
        switch (deviceType) {
          case DeviceType.desktop:
            columns = desktopColumns ?? tabletColumns ?? 4;
          case DeviceType.tablet:
            columns = tabletColumns ?? 3;
          case DeviceType.mobile:
            columns = mobileColumns ?? 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: runSpacing,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

/// Liste responsive qui passe en grille sur tablette
class ResponsiveList extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final Axis mobileAxis;
  final double? itemExtent;

  const ResponsiveList({
    super.key,
    required this.children,
    this.spacing = 16,
    this.mobileAxis = Axis.vertical,
    this.itemExtent,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ResponsiveService.getListColumns(constraints.maxWidth);

        if (columns == 1) {
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: mobileAxis,
            itemCount: children.length,
            separatorBuilder: (_, __) => SizedBox(
              width: mobileAxis == Axis.horizontal ? spacing : 0,
              height: mobileAxis == Axis.vertical ? spacing : 0,
            ),
            itemBuilder: (_, index) => children[index],
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 1,
          ),
          itemCount: children.length,
          itemBuilder: (_, index) => children[index],
        );
      },
    );
  }
}

/// Container avec largeur maximale centrée (pour tablettes/desktop)
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
}

/// Master-Detail layout pour tablettes (liste + détail)
class MasterDetailLayout extends StatelessWidget {
  final Widget master;
  final Widget? detail;
  final Widget? emptyDetail;
  final double masterWidth;

  const MasterDetailLayout({
    super.key,
    required this.master,
    this.detail,
    this.emptyDetail,
    this.masterWidth = 350,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLarge = constraints.maxWidth >= ResponsiveService.mobileMaxWidth;

        if (!isLarge) return master;

        return Row(
          children: [
            SizedBox(width: masterWidth, child: master),
            const VerticalDivider(width: 1),
            Expanded(
              child: detail ?? emptyDetail ?? const Center(
                child: Text('Sélectionnez un élément'),
              ),
            ),
          ],
        );
      },
    );
  }
}
