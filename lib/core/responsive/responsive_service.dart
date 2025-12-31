import 'package:flutter/material.dart';

enum DeviceType { mobile, tablet, desktop }

class ResponsiveService {
  ResponsiveService._();

  static const double mobileMaxWidth = 600;
  static const double tabletMaxWidth = 1200;

  static DeviceType getDeviceType(double width) {
    if (width < mobileMaxWidth) return DeviceType.mobile;
    if (width < tabletMaxWidth) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  static int getGridColumns(double width) {
    if (width < mobileMaxWidth) return 2;
    if (width < 768) return 3;
    if (width < tabletMaxWidth) return 4;
    return 6;
  }

  static int getListColumns(double width) {
    if (width < mobileMaxWidth) return 1;
    if (width < 1024) return 2;
    return 3;
  }
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  DeviceType get deviceType => ResponsiveService.getDeviceType(screenWidth);
  bool get isMobile => deviceType == DeviceType.mobile;
  bool get isTablet => deviceType == DeviceType.tablet;
  bool get isDesktop => deviceType == DeviceType.desktop;
  bool get isLargeDevice => isTablet || isDesktop;
  int get gridColumns => ResponsiveService.getGridColumns(screenWidth);
  int get listColumns => ResponsiveService.getListColumns(screenWidth);

  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    switch (deviceType) {
      case DeviceType.desktop: return desktop ?? tablet ?? mobile;
      case DeviceType.tablet: return tablet ?? mobile;
      case DeviceType.mobile: return mobile;
    }
  }
}
