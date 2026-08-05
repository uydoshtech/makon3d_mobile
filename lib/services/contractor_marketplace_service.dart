import 'package:dio/dio.dart';

import 'package:makon3d_mobile/models/contractor_job.dart';
import 'package:makon3d_mobile/models/contractor_listing.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/services/auth/session_manager.dart';
import 'package:makon3d_mobile/services/scan_upload_service.dart';

abstract final class ContractorMarketplaceService {
  static final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: ScanUploadService.basePath,
            connectTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await SessionManager.getToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
          ),
        );

  static Future<ContractorJob> publishJob({
    required MakonProject project,
    required ContractorListing listing,
  }) async {
    final scans = _projectScans(project);
    final response = await _dio.put<Map<String, dynamic>>(
      '/makon3d/contractor-jobs/by-project/${Uri.encodeComponent(project.id)}',
      data: <String, dynamic>{
        'project_name': project.name,
        'area_m2': _totalArea(scans),
        'room_count': _roomCount(project),
        'preview_scan_id': _previewScanId(scans),
        'listing': listing.toJson(),
      },
    );
    return _jobFromEnvelope(response.data);
  }

  static Future<List<ContractorJob>> listFeed({
    ContractorWorkType? workType,
    String? location,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/makon3d/contractor-jobs/feed',
      queryParameters: <String, dynamic>{
        if (workType != null) 'work_type': workType.wireValue,
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
      },
    );
    return _jobsFromList(response.data?['jobs']);
  }

  static Future<List<ContractorJob>> listMine() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/makon3d/contractor-jobs/mine',
    );
    return _jobsFromList(response.data?['jobs']);
  }

  static Future<List<ContractorJob>> listMyOffers() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/makon3d/contractor-jobs/my-offers',
    );
    return _jobsFromList(response.data?['jobs']);
  }

  static Future<ContractorJob> getJob(int jobId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/makon3d/contractor-jobs/$jobId',
    );
    return _jobFromEnvelope(response.data);
  }

  static Future<ContractorOffer> submitOffer({
    required int jobId,
    required double amountMillion,
    required int durationDays,
    int? warrantyMonths,
    String? comment,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/makon3d/contractor-jobs/$jobId/offers',
      data: <String, dynamic>{
        'amount_million': amountMillion,
        'duration_days': durationDays,
        'warranty_months': warrantyMonths,
        'comment': comment,
      },
    );
    final raw = response.data?['offer'];
    if (raw is! Map) throw const FormatException('Missing contractor offer');
    return ContractorOffer.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<ContractorJob> acceptOffer(int offerId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/makon3d/contractor-offers/$offerId/accept',
    );
    return _jobFromEnvelope(response.data);
  }

  static Future<ContractorJob> revealPrivateAccess(int jobId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/makon3d/contractor-jobs/$jobId/reveal-access',
    );
    return _jobFromEnvelope(response.data);
  }

  static Future<ContractorJob> closeJob(int jobId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/makon3d/contractor-jobs/$jobId/close',
    );
    return _jobFromEnvelope(response.data);
  }

  static ContractorJob _jobFromEnvelope(Map<String, dynamic>? data) {
    final raw = data?['job'];
    if (raw is! Map) throw const FormatException('Missing contractor job');
    return ContractorJob.fromJson(Map<String, dynamic>.from(raw));
  }

  static List<ContractorJob> _jobsFromList(Object? raw) {
    if (raw is! List) return const <ContractorJob>[];
    return raw
        .whereType<Map>()
        .map((item) => ContractorJob.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static List<HousingScan> _projectScans(MakonProject project) => <HousingScan>[
    if (project.entireHousingScan != null) project.entireHousingScan!,
    for (final room in project.rooms)
      if (room.scan != null) room.scan!,
  ];

  static double? _totalArea(List<HousingScan> scans) {
    final areas = scans.map((scan) => scan.floorAreaM2).whereType<double>();
    if (areas.isEmpty) return null;
    return areas.fold<double>(0, (total, area) => total + area);
  }

  static int? _roomCount(MakonProject project) {
    if (project.rooms.isNotEmpty) return project.rooms.length;
    final detected = project.entireHousingScan?.roomTypes.length ?? 0;
    return detected > 0 ? detected : null;
  }

  static int? _previewScanId(List<HousingScan> scans) {
    for (final scan in scans) {
      if (scan.remoteScanId case final id?) return id;
    }
    return null;
  }
}
