/// The way a customer wants to collect prices from contractors.
enum ContractorBudgetMode {
  openOffers('open_offers'),
  range('range'),
  competition('competition');

  const ContractorBudgetMode(this.wireValue);

  final String wireValue;

  static ContractorBudgetMode fromWireValue(Object? value) {
    return values.firstWhere(
      (mode) => mode.wireValue == value,
      orElse: () => ContractorBudgetMode.openOffers,
    );
  }
}

enum ContractorListingStatus {
  open('open'),
  assigned('assigned'),
  closed('closed'),
  cancelled('cancelled');

  const ContractorListingStatus(this.wireValue);

  final String wireValue;

  static ContractorListingStatus fromWireValue(Object? value) {
    return values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => ContractorListingStatus.open,
    );
  }
}

/// Stable work identifiers stored independently from the current UI language.
enum ContractorWorkType {
  fullRenovation('full_renovation'),
  laminate('laminate'),
  wallpaper('wallpaper'),
  tile('tile'),
  painting('painting'),
  electrical('electrical'),
  plumbing('plumbing'),
  doors('doors'),
  baseboard('baseboard'),
  other('other');

  const ContractorWorkType(this.wireValue);

  final String wireValue;

  static ContractorWorkType? tryFromWireValue(Object? value) {
    for (final type in values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}

enum ContractorVolumeUnit {
  squareMeters('m2'),
  meters('m'),
  pieces('pcs');

  const ContractorVolumeUnit(this.wireValue);

  final String wireValue;

  static ContractorVolumeUnit fromWireValue(Object? value) {
    return values.firstWhere(
      (unit) => unit.wireValue == value,
      orElse: () => ContractorVolumeUnit.squareMeters,
    );
  }
}

/// A Makon3D-derived quantity included in the contractor brief.
class ContractorWorkVolume {
  const ContractorWorkVolume({
    required this.type,
    required this.amount,
    required this.unit,
  });

  final ContractorWorkType type;
  final double amount;
  final ContractorVolumeUnit unit;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.wireValue,
    'amount': amount,
    'unit': unit.wireValue,
  };

  static ContractorWorkVolume? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final type = ContractorWorkType.tryFromWireValue(json['type']);
    final amount = (json['amount'] as num?)?.toDouble();
    if (type == null || amount == null || amount <= 0) return null;
    return ContractorWorkVolume(
      type: type,
      amount: amount,
      unit: ContractorVolumeUnit.fromWireValue(json['unit']),
    );
  }
}

/// Customer-controlled visibility for a public contractor brief.
class ContractorListingVisibility {
  const ContractorListingVisibility({
    this.show3dPreview = true,
    this.showFloorPlan = true,
    this.showMeasurements = true,
    this.showMaterialEstimate = true,
    this.showPhotos = false,
    this.showExactAddress = false,
  });

  final bool show3dPreview;
  final bool showFloorPlan;
  final bool showMeasurements;
  final bool showMaterialEstimate;
  final bool showPhotos;
  final bool showExactAddress;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'show3dPreview': show3dPreview,
    'showFloorPlan': showFloorPlan,
    'showMeasurements': showMeasurements,
    'showMaterialEstimate': showMaterialEstimate,
    'showPhotos': showPhotos,
    'showExactAddress': showExactAddress,
  };

  factory ContractorListingVisibility.fromJson(Object? value) {
    if (value is! Map) return const ContractorListingVisibility();
    final json = Map<String, dynamic>.from(value);
    return ContractorListingVisibility(
      show3dPreview: json['show3dPreview'] as bool? ?? true,
      showFloorPlan: json['showFloorPlan'] as bool? ?? true,
      showMeasurements: json['showMeasurements'] as bool? ?? true,
      showMaterialEstimate: json['showMaterialEstimate'] as bool? ?? true,
      showPhotos: json['showPhotos'] as bool? ?? false,
      showExactAddress: json['showExactAddress'] as bool? ?? false,
    );
  }
}

/// Snapshot of the brief made searchable to contractors.
///
/// It lives inside [MakonProject]'s JSON so it survives local persistence and
/// the existing project backup sync. A marketplace API can consume the same
/// stable wire values without depending on localized labels.
class ContractorListing {
  const ContractorListing({
    required this.workTypes,
    required this.publicLocation,
    required this.visibility,
    required this.budgetMode,
    required this.startDate,
    required this.desiredDurationDays,
    required this.siteVisitAvailable,
    required this.publishedAt,
    this.detectedVolumes = const <ContractorWorkVolume>[],
    this.budgetMinMillion,
    this.budgetMaxMillion,
    this.comment,
    this.responseCount = 0,
    this.remoteJobId,
    this.status = ContractorListingStatus.open,
  });

  final List<ContractorWorkType> workTypes;
  final String publicLocation;
  final ContractorListingVisibility visibility;
  final ContractorBudgetMode budgetMode;
  final List<ContractorWorkVolume> detectedVolumes;
  final double? budgetMinMillion;
  final double? budgetMaxMillion;
  final DateTime startDate;
  final int desiredDurationDays;
  final bool siteVisitAvailable;
  final String? comment;
  final DateTime publishedAt;
  final int responseCount;
  final int? remoteJobId;
  final ContractorListingStatus status;

  ContractorListing copyWith({
    int? responseCount,
    int? remoteJobId,
    ContractorListingStatus? status,
  }) {
    return ContractorListing(
      workTypes: workTypes,
      publicLocation: publicLocation,
      visibility: visibility,
      budgetMode: budgetMode,
      detectedVolumes: detectedVolumes,
      budgetMinMillion: budgetMinMillion,
      budgetMaxMillion: budgetMaxMillion,
      startDate: startDate,
      desiredDurationDays: desiredDurationDays,
      siteVisitAvailable: siteVisitAvailable,
      comment: comment,
      publishedAt: publishedAt,
      responseCount: responseCount ?? this.responseCount,
      remoteJobId: remoteJobId ?? this.remoteJobId,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'workTypes': workTypes.map((type) => type.wireValue).toList(),
    'publicLocation': publicLocation,
    'visibility': visibility.toJson(),
    'budgetMode': budgetMode.wireValue,
    'detectedVolumes': detectedVolumes
        .map((volume) => volume.toJson())
        .toList(),
    'budgetMinMillion': budgetMinMillion,
    'budgetMaxMillion': budgetMaxMillion,
    'startDate': startDate.toIso8601String(),
    'desiredDurationDays': desiredDurationDays,
    'siteVisitAvailable': siteVisitAvailable,
    'comment': comment,
    'publishedAt': publishedAt.toIso8601String(),
    'responseCount': responseCount,
    'remoteJobId': remoteJobId,
    'status': status.wireValue,
  };

  static ContractorListing? tryFromJson(Object? value) {
    if (value is! Map) return null;
    try {
      final json = Map<String, dynamic>.from(value);
      final workTypes = (json['workTypes'] as List? ?? const <Object>[])
          .map(ContractorWorkType.tryFromWireValue)
          .whereType<ContractorWorkType>()
          .toList(growable: false);
      final volumes = (json['detectedVolumes'] as List? ?? const <Object>[])
          .map(ContractorWorkVolume.tryFromJson)
          .whereType<ContractorWorkVolume>()
          .toList(growable: false);
      final startDate = DateTime.tryParse(json['startDate']?.toString() ?? '');
      final publishedAt = DateTime.tryParse(
        json['publishedAt']?.toString() ?? '',
      );
      final publicLocation = json['publicLocation']?.toString().trim() ?? '';
      if (workTypes.isEmpty ||
          publicLocation.isEmpty ||
          startDate == null ||
          publishedAt == null) {
        return null;
      }
      return ContractorListing(
        workTypes: workTypes,
        publicLocation: publicLocation,
        visibility: ContractorListingVisibility.fromJson(json['visibility']),
        budgetMode: ContractorBudgetMode.fromWireValue(json['budgetMode']),
        detectedVolumes: volumes,
        budgetMinMillion: (json['budgetMinMillion'] as num?)?.toDouble(),
        budgetMaxMillion: (json['budgetMaxMillion'] as num?)?.toDouble(),
        startDate: startDate,
        desiredDurationDays:
            (json['desiredDurationDays'] as num?)?.toInt() ?? 30,
        siteVisitAvailable: json['siteVisitAvailable'] as bool? ?? false,
        comment: json['comment'] as String?,
        publishedAt: publishedAt,
        responseCount: (json['responseCount'] as num?)?.toInt() ?? 0,
        remoteJobId: (json['remoteJobId'] as num?)?.toInt(),
        status: ContractorListingStatus.fromWireValue(json['status']),
      );
    } catch (_) {
      return null;
    }
  }
}
