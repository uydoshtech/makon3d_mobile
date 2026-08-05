import 'package:flutter_test/flutter_test.dart';

import 'package:makon3d_mobile/models/contractor_listing.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:room_scan_kit/scan_flow/scan_flow.dart';

void main() {
  test('contractor listing survives project JSON round-trip', () {
    final listing = ContractorListing(
      workTypes: const <ContractorWorkType>[
        ContractorWorkType.fullRenovation,
        ContractorWorkType.laminate,
      ],
      publicLocation: 'Mirabad, Tashkent',
      visibility: const ContractorListingVisibility(),
      budgetMode: ContractorBudgetMode.range,
      detectedVolumes: const <ContractorWorkVolume>[
        ContractorWorkVolume(
          type: ContractorWorkType.laminate,
          amount: 68.5,
          unit: ContractorVolumeUnit.squareMeters,
        ),
      ],
      budgetMinMillion: 20,
      budgetMaxMillion: 30,
      startDate: DateTime.utc(2026, 8, 15),
      desiredDurationDays: 30,
      siteVisitAvailable: true,
      comment: 'The apartment is vacant.',
      publishedAt: DateTime.utc(2026, 8, 6),
      responseCount: 7,
      remoteJobId: 91,
      status: ContractorListingStatus.assigned,
    );
    final project = MakonProject(
      id: 'project-1',
      name: 'Baha',
      scanMode: ScanMode.entireHousing,
      createdAt: DateTime.utc(2026, 8, 1),
      contractorListing: listing,
    );

    final restored = MakonProject.fromJson(project.toJson());
    final restoredListing = restored.contractorListing;

    expect(restoredListing, isNotNull);
    expect(restoredListing!.publicLocation, 'Mirabad, Tashkent');
    expect(restoredListing.workTypes, contains(ContractorWorkType.laminate));
    expect(restoredListing.detectedVolumes.single.amount, 68.5);
    expect(restoredListing.visibility.showExactAddress, isFalse);
    expect(restoredListing.budgetMode, ContractorBudgetMode.range);
    expect(restoredListing.budgetMinMillion, 20);
    expect(restoredListing.responseCount, 7);
    expect(restoredListing.remoteJobId, 91);
    expect(restoredListing.status, ContractorListingStatus.assigned);
  });

  test('invalid contractor listing JSON is ignored safely', () {
    final project = MakonProject.fromJson(<String, dynamic>{
      'id': 'legacy-project',
      'name': 'Legacy',
      'scanMode': 'entireHousing',
      'createdAt': DateTime.utc(2026).toIso8601String(),
      'contractorListing': <String, dynamic>{
        'workTypes': <String>[],
        'publicLocation': '',
      },
    });

    expect(project.contractorListing, isNull);
  });
}
