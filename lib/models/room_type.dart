import 'package:flutter/material.dart';

/// Room category for Makon room-by-room projects.
enum RoomType {
  livingRoom,
  bedroom,
  kitchen,
  bathroom,
  hallway,
  balcony,
  garage,
  other;

  String get wireValue => name;

  /// Localization key for display name.
  String get titleKey => 'room_type_$name';

  IconData get icon => switch (this) {
    RoomType.livingRoom => Icons.weekend_outlined,
    RoomType.bedroom => Icons.bed_outlined,
    RoomType.kitchen => Icons.kitchen_outlined,
    RoomType.bathroom => Icons.bathtub_outlined,
    RoomType.hallway => Icons.door_front_door_outlined,
    RoomType.balcony => Icons.balcony_outlined,
    RoomType.garage => Icons.garage_outlined,
    RoomType.other => Icons.meeting_room_outlined,
  };

  static RoomType? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final type in RoomType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}
