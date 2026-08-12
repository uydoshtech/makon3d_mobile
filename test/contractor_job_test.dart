import 'package:flutter_test/flutter_test.dart';

import 'package:makon3d_mobile/models/contractor_job.dart';
import 'package:makon3d_mobile/models/contractor_listing.dart';

void main() {
  test('contractor job parses feed and own-offer fields', () {
    final job = ContractorJob.fromJson(<String, dynamic>{
      'id': '45',
      'status': 'open',
      'public_location': 'Мирабадский район, Ташкент',
      'work_types': <String>['laminate', 'wallpaper'],
      'detected_volumes': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'laminate', 'amount': 87.7, 'unit': 'm2'},
      ],
      'visibility': <String, dynamic>{'show3dPreview': true},
      'budget_mode': 'range',
      'budget_min_million': 20,
      'budget_max_million': '30.5',
      'start_date': '2026-08-15',
      'duration_days': 30,
      'site_visit_available': true,
      'area_m2': '87.7',
      'room_count': 3,
      'offer_count': 4,
      'published_at': '2026-08-12T14:30:00.000Z',
      'contact_revealed': false,
      'my_offer': <String, dynamic>{
        'id': 8,
        'job_id': 45,
        'contractor_user_id': 12,
        'amount_million': '24.5',
        'duration_days': 25,
        'status': 'pending',
      },
    });

    expect(job.id, 45);
    expect(job.status, ContractorListingStatus.open);
    expect(job.workTypes, contains(ContractorWorkType.laminate));
    expect(job.detectedVolumes.single.amount, 87.7);
    expect(job.budgetMaxMillion, 30.5);
    expect(job.myOffer?.amountMillion, 24.5);
    expect(job.offerCount, 4);
    expect(job.publishedAt, DateTime.utc(2026, 8, 12, 14, 30));
  });

  test('selected contractor receives private access fields', () {
    final job = ContractorJob.fromJson(<String, dynamic>{
      'id': 45,
      'status': 'assigned',
      'public_location': 'Мирабадский район, Ташкент',
      'work_types': <String>['painting'],
      'detected_volumes': <Object>[],
      'visibility': <String, dynamic>{},
      'budget_mode': 'open_offers',
      'start_date': '2026-08-15',
      'duration_days': 20,
      'site_visit_available': false,
      'offer_count': 1,
      'contact_revealed': true,
      'private_access': <String, dynamic>{
        'exact_address': 'ул. Авлиё-Ата, дом 37',
        'customer_phone': '+998901234567',
        'customer_name': 'Баха',
      },
    });

    expect(job.isAssigned, isTrue);
    expect(job.privateAccess?.exactAddress, 'ул. Авлиё-Ата, дом 37');
    expect(job.privateAccess?.customerPhone, '+998901234567');
  });

  test(
    'contractor jobs sort by publication freshness with stable fallback',
    () {
      ContractorJob job(int id, String? publishedAt) =>
          ContractorJob.fromJson(<String, dynamic>{
            'id': id,
            'status': 'open',
            'start_date': '2026-09-01',
            if (publishedAt != null) 'published_at': publishedAt,
          });

      final jobs = <ContractorJob>[
        job(30, null),
        job(10, '2026-08-10T09:00:00.000Z'),
        job(12, '2026-08-12T09:00:00.000Z'),
        job(11, '2026-08-12T09:00:00.000Z'),
      ]..sort(compareContractorJobsByFreshness);

      expect(jobs.map((item) => item.id), <int>[12, 11, 10, 30]);
    },
  );
}
