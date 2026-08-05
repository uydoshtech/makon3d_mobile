import 'package:makon3d_mobile/models/contractor_listing.dart';

class ContractorOffer {
  const ContractorOffer({
    required this.id,
    required this.jobId,
    required this.contractorUserId,
    required this.amountMillion,
    required this.durationDays,
    required this.status,
    this.contractorName,
    this.contractorAvatarUrl,
    this.warrantyMonths,
    this.comment,
  });

  final int id;
  final int jobId;
  final int contractorUserId;
  final String? contractorName;
  final String? contractorAvatarUrl;
  final double? amountMillion;
  final int durationDays;
  final int? warrantyMonths;
  final String? comment;
  final String status;

  bool get isAccepted => status == 'accepted';
  bool get isPending => status == 'pending';

  factory ContractorOffer.fromJson(Map<String, dynamic> json) {
    return ContractorOffer(
      id: _asInt(json['id']) ?? 0,
      jobId: _asInt(json['job_id']) ?? 0,
      contractorUserId: _asInt(json['contractor_user_id']) ?? 0,
      contractorName: _asText(json['contractor_name']),
      contractorAvatarUrl: _asText(json['contractor_avatar_url']),
      amountMillion: _asDouble(json['amount_million']),
      durationDays: _asInt(json['duration_days']) ?? 0,
      warrantyMonths: _asInt(json['warranty_months']),
      comment: _asText(json['comment']),
      status: _asText(json['status']) ?? 'pending',
    );
  }
}

class ContractorPrivateAccess {
  const ContractorPrivateAccess({
    this.exactAddress,
    this.customerPhone,
    this.customerName,
  });

  final String? exactAddress;
  final String? customerPhone;
  final String? customerName;

  factory ContractorPrivateAccess.fromJson(Map<String, dynamic> json) {
    return ContractorPrivateAccess(
      exactAddress: _asText(json['exact_address']),
      customerPhone: _asText(json['customer_phone']),
      customerName: _asText(json['customer_name']),
    );
  }
}

class ContractorJob {
  const ContractorJob({
    required this.id,
    required this.status,
    required this.publicLocation,
    required this.workTypes,
    required this.detectedVolumes,
    required this.visibility,
    required this.budgetMode,
    required this.startDate,
    required this.durationDays,
    required this.siteVisitAvailable,
    required this.offerCount,
    required this.contactRevealed,
    required this.offers,
    this.projectId,
    this.projectName,
    this.budgetMinMillion,
    this.budgetMaxMillion,
    this.comment,
    this.areaM2,
    this.roomCount,
    this.previewScanId,
    this.selectedOfferId,
    this.myOffer,
    this.privateAccess,
  });

  final int id;
  final String? projectId;
  final String? projectName;
  final ContractorListingStatus status;
  final String publicLocation;
  final List<ContractorWorkType> workTypes;
  final List<ContractorWorkVolume> detectedVolumes;
  final ContractorListingVisibility visibility;
  final ContractorBudgetMode budgetMode;
  final double? budgetMinMillion;
  final double? budgetMaxMillion;
  final DateTime startDate;
  final int durationDays;
  final bool siteVisitAvailable;
  final String? comment;
  final double? areaM2;
  final int? roomCount;
  final int? previewScanId;
  final int offerCount;
  final int? selectedOfferId;
  final bool contactRevealed;
  final List<ContractorOffer> offers;
  final ContractorOffer? myOffer;
  final ContractorPrivateAccess? privateAccess;

  bool get isOpen => status == ContractorListingStatus.open;
  bool get isAssigned => status == ContractorListingStatus.assigned;

  factory ContractorJob.fromJson(Map<String, dynamic> json) {
    final rawDate = _asText(json['start_date']);
    final rawOffers = json['offers'];
    final rawMyOffer = json['my_offer'];
    final rawPrivateAccess = json['private_access'];
    return ContractorJob(
      id: _asInt(json['id']) ?? 0,
      projectId: _asText(json['project_id']),
      projectName: _asText(json['project_name']),
      status: ContractorListingStatus.fromWireValue(json['status']),
      publicLocation: _asText(json['public_location']) ?? '',
      workTypes: (json['work_types'] as List? ?? const <Object>[])
          .map(ContractorWorkType.tryFromWireValue)
          .whereType<ContractorWorkType>()
          .toList(growable: false),
      detectedVolumes: (json['detected_volumes'] as List? ?? const <Object>[])
          .map(ContractorWorkVolume.tryFromJson)
          .whereType<ContractorWorkVolume>()
          .toList(growable: false),
      visibility: ContractorListingVisibility.fromJson(json['visibility']),
      budgetMode: ContractorBudgetMode.fromWireValue(json['budget_mode']),
      budgetMinMillion: _asDouble(json['budget_min_million']),
      budgetMaxMillion: _asDouble(json['budget_max_million']),
      startDate:
          DateTime.tryParse(rawDate ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      durationDays: _asInt(json['duration_days']) ?? 0,
      siteVisitAvailable: json['site_visit_available'] == true,
      comment: _asText(json['comment']),
      areaM2: _asDouble(json['area_m2']),
      roomCount: _asInt(json['room_count']),
      previewScanId: _asInt(json['preview_scan_id']),
      offerCount: _asInt(json['offer_count']) ?? 0,
      selectedOfferId: _asInt(json['selected_offer_id']),
      contactRevealed: json['contact_revealed'] == true,
      offers: rawOffers is List
          ? rawOffers
                .whereType<Map>()
                .map(
                  (item) =>
                      ContractorOffer.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <ContractorOffer>[],
      myOffer: rawMyOffer is Map
          ? ContractorOffer.fromJson(Map<String, dynamic>.from(rawMyOffer))
          : null,
      privateAccess: rawPrivateAccess is Map
          ? ContractorPrivateAccess.fromJson(
              Map<String, dynamic>.from(rawPrivateAccess),
            )
          : null,
    );
  }
}

int? _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String? _asText(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
