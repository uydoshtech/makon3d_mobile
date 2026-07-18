/// Room category for Makon room-by-room projects.
enum RoomType {
  livingRoom,
  bedroom,
  kitchen,
  bathroom,
  hallway,
  other;

  String get wireValue => name;

  /// Localization key for display name.
  String get titleKey => 'room_type_$name';

  static RoomType? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final type in RoomType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}
