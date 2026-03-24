import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/api_endpoints.dart';
import '../utils/app_logger.dart';

/// Result returned by [UpdateService.checkForUpdate].
class UpdateCheckResult {
  /// No update needed — app is up to date.
  static const UpdateCheckResult upToDate = UpdateCheckResult._internal(
    hasUpdate: false,
    isForceUpdate: false,
    latestVersion: '',
    downloadUrl: '',
    releaseNotes: '',
  );

  final bool hasUpdate;
  final bool isForceUpdate;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;

  const UpdateCheckResult._internal({
    required this.hasUpdate,
    required this.isForceUpdate,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  factory UpdateCheckResult.available({
    required bool isForce,
    required String version,
    required String url,
    required String notes,
  }) =>
      UpdateCheckResult._internal(
        hasUpdate: true,
        isForceUpdate: isForce,
        latestVersion: version,
        downloadUrl: url,
        releaseNotes: notes,
      );
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  // Plain Dio — no auth interceptor, this is a public endpoint.
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  /// Fetches [ApiEndpoints.latestRelease] and compares [build_number] with the
  /// locally installed build number from [PackageInfo].
  ///
  /// Returns [UpdateCheckResult.upToDate] on any network / parse error so the
  /// app is never blocked by a server outage.
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final localBuild = int.tryParse(info.buildNumber) ?? 0;

      final response = await _dio.get(ApiEndpoints.latestRelease);
      final data = response.data as Map<String, dynamic>;

      final remoteBuild = (data['build_number'] as num?)?.toInt() ?? 0;

      if (remoteBuild <= localBuild) return UpdateCheckResult.upToDate;

      return UpdateCheckResult.available(
        isForce: data['is_force_update'] as bool? ?? false,
        version: data['version_number'] as String? ?? '',
        url: data['download_url'] as String? ?? '',
        notes: data['release_notes'] as String? ?? '',
      );
    } on SocketException {
      // No internet — silently skip update check.
      AppLogger.w('UpdateService: no network, skipping version check');
      return UpdateCheckResult.upToDate;
    } on DioException catch (e) {
      AppLogger.w('UpdateService: ${e.message}');
      return UpdateCheckResult.upToDate;
    } catch (e) {
      AppLogger.e('UpdateService unexpected error: $e');
      return UpdateCheckResult.upToDate;
    }
  }
}
