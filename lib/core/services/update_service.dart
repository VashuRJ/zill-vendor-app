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
  /// Sends [current_build] so the server can enforce [min_supported_build].
  ///
  /// Returns [UpdateCheckResult.upToDate] on any network / parse error so the
  /// app is never blocked by a server outage.
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      // split-per-abi adds prefix: armeabi-v7a=+1000, arm64-v8a=+2000, x86_64=+3000
      // Strip the ABI prefix to get the raw build number for comparison
      final rawBuildCode = int.tryParse(info.buildNumber) ?? 0;
      final localBuild = rawBuildCode % 1000;
      AppLogger.i('[UpdateService] Local build: $localBuild (raw=$rawBuildCode, ${info.version}+${info.buildNumber})');

      final response = await _dio.get(
        ApiEndpoints.latestRelease,
        queryParameters: {
          'app_type': 'vendor',
          'current_build': localBuild,
        },
      );

      AppLogger.i('[UpdateService] Response status: ${response.statusCode}');
      AppLogger.i('[UpdateService] Response data: ${response.data}');

      final data = response.data as Map<String, dynamic>;

      final remoteBuild = (data['build_number'] as num?)?.toInt() ?? 0;
      final isForce = data['is_force_update'] as bool? ?? false;

      AppLogger.i('[UpdateService] Remote build: $remoteBuild | Local build: $localBuild | Force: $isForce');

      if (remoteBuild <= localBuild) {
        AppLogger.i('[UpdateService] App is up to date (remote $remoteBuild <= local $localBuild)');
        return UpdateCheckResult.upToDate;
      }

      AppLogger.i('[UpdateService] UPDATE AVAILABLE! $localBuild -> $remoteBuild');
      return UpdateCheckResult.available(
        isForce: isForce,
        version: data['version_number'] as String? ?? '',
        url: data['download_url'] as String? ?? '',
        notes: data['release_notes'] as String? ?? '',
      );
    } on SocketException catch (e) {
      AppLogger.w('[UpdateService] No network: $e');
      return UpdateCheckResult.upToDate;
    } on DioException catch (e) {
      AppLogger.e('[UpdateService] DioException: ${e.type} — ${e.message}');
      AppLogger.e('[UpdateService] DioException response: ${e.response?.data}');
      return UpdateCheckResult.upToDate;
    } catch (e, stack) {
      AppLogger.e('[UpdateService] UNEXPECTED ERROR: $e');
      AppLogger.e('[UpdateService] Stack: $stack');
      return UpdateCheckResult.upToDate;
    }
  }

  /// Call after user starts the APK download to track download count.
  Future<void> trackDownload(int buildNumber) async {
    try {
      await _dio.post(
        ApiEndpoints.trackDownload,
        data: {'app_type': 'vendor', 'build_number': buildNumber},
      );
    } catch (_) {
      // Non-critical — silently ignore
    }
  }
}
