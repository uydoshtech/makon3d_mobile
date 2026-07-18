import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/models/room_type.dart';

/// One independently scanned room inside a room-by-room Makon project.
class ProjectRoom {
  const ProjectRoom({
    required this.id,
    required this.roomType,
    required this.createdAt,
    this.name,
    this.scan,
  });

  final String id;
  final RoomType roomType;
  final DateTime createdAt;
  final String? name;
  final HousingScan? scan;

  bool get isScanned => scan?.hasModel == true;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'roomType': roomType.wireValue,
        'createdAt': createdAt.toIso8601String(),
        'name': name,
        'scan': scan?.toJson(),
      };

  factory ProjectRoom.fromJson(Map<String, dynamic> json) {
    return ProjectRoom(
      id: json['id'] as String? ?? '',
      roomType: RoomType.tryParse(json['roomType'] as String?) ?? RoomType.other,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      name: json['name'] as String?,
      scan: json['scan'] is Map<String, dynamic>
          ? HousingScan.fromJson(json['scan'] as Map<String, dynamic>)
          : null,
    );
  }

  ProjectRoom copyWith({
    RoomType? roomType,
    String? name,
    HousingScan? scan,
  }) {
    return ProjectRoom(
      id: id,
      roomType: roomType ?? this.roomType,
      createdAt: createdAt,
      name: name ?? this.name,
      scan: scan ?? this.scan,
    );
  }
}
