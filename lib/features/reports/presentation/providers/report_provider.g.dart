// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$reportRemoteDataSourceHash() =>
    r'414af5165e7b2012bd8d79d41008b497fb8cf8cf';

/// See also [reportRemoteDataSource].
@ProviderFor(reportRemoteDataSource)
final reportRemoteDataSourceProvider =
    AutoDisposeProvider<ReportRemoteDataSource>.internal(
      reportRemoteDataSource,
      name: r'reportRemoteDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$reportRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReportRemoteDataSourceRef =
    AutoDisposeProviderRef<ReportRemoteDataSource>;
String _$reportRepositoryHash() => r'c57c142ef8a936b4b65b8ffbd6b98909ce8d20e5';

/// See also [reportRepository].
@ProviderFor(reportRepository)
final reportRepositoryProvider = AutoDisposeProvider<ReportRepository>.internal(
  reportRepository,
  name: r'reportRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$reportRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReportRepositoryRef = AutoDisposeProviderRef<ReportRepository>;
String _$myReportsHash() => r'6cafe16190101f9aa01a0957d69fc279d517d9ed';

/// See also [myReports].
@ProviderFor(myReports)
final myReportsProvider = StreamProvider<List<ReportEntity>>.internal(
  myReports,
  name: r'myReportsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$myReportsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyReportsRef = StreamProviderRef<List<ReportEntity>>;
String _$allReportsHash() => r'58bd3bd02a43f7af3c9e0d66d705853f8856ff96';

/// See also [allReports].
@ProviderFor(allReports)
final allReportsProvider = StreamProvider<List<ReportEntity>>.internal(
  allReports,
  name: r'allReportsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$allReportsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AllReportsRef = StreamProviderRef<List<ReportEntity>>;
String _$pendingReportsStreamHash() =>
    r'd4cc0e4a0781f47e4fe8cc132387d29cb5bbbbff';

/// See also [pendingReportsStream].
@ProviderFor(pendingReportsStream)
final pendingReportsStreamProvider =
    StreamProvider<List<ReportEntity>>.internal(
      pendingReportsStream,
      name: r'pendingReportsStreamProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$pendingReportsStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingReportsStreamRef = StreamProviderRef<List<ReportEntity>>;
String _$reportStatisticsHash() => r'4461766a841263bb2565a3b3548117cdd35bae82';

/// See also [reportStatistics].
@ProviderFor(reportStatistics)
final reportStatisticsProvider =
    AutoDisposeFutureProvider<ReportStatistics>.internal(
      reportStatistics,
      name: r'reportStatisticsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$reportStatisticsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReportStatisticsRef = AutoDisposeFutureProviderRef<ReportStatistics>;
String _$pendingReportsCountHash() =>
    r'42561de948ae74b7e66bfd4d245fbb951625103a';

/// See also [pendingReportsCount].
@ProviderFor(pendingReportsCount)
final pendingReportsCountProvider = AutoDisposeFutureProvider<int>.internal(
  pendingReportsCount,
  name: r'pendingReportsCountProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$pendingReportsCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingReportsCountRef = AutoDisposeFutureProviderRef<int>;
String _$submitReportNotifierHash() =>
    r'edea36c9809f3357cfe9c2edb4f63c0a2d3dda8b';

/// See also [SubmitReportNotifier].
@ProviderFor(SubmitReportNotifier)
final submitReportNotifierProvider = AutoDisposeNotifierProvider<
  SubmitReportNotifier,
  AsyncValue<void>
>.internal(
  SubmitReportNotifier.new,
  name: r'submitReportNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$submitReportNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SubmitReportNotifier = AutoDisposeNotifier<AsyncValue<void>>;
String _$adminReportNotifierHash() =>
    r'126a16e53c18fa45a97f5a7e18ac060f4eb9d448';

/// See also [AdminReportNotifier].
@ProviderFor(AdminReportNotifier)
final adminReportNotifierProvider =
    AutoDisposeNotifierProvider<AdminReportNotifier, AsyncValue<void>>.internal(
      AdminReportNotifier.new,
      name: r'adminReportNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$adminReportNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AdminReportNotifier = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
