import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

/// Supported app locales (uz, ru, en) — same set as UyDosh.
const List<Locale> supportedLocales = [
  Locale("uz"),
  Locale("ru"),
  Locale("en"),
];

/// Persisted under `selected_language` so the iOS AppDelegate can read it as
/// `flutter.selected_language` from NSUserDefaults and set `AppleLanguages`
/// before RoomPlan/ARKit resolve their localized strings.
class LanguageState extends ChangeNotifier {
  LanguageState._();

  static final LanguageState _instance = LanguageState._();
  factory LanguageState() => _instance;

  static const _prefsKey = "selected_language";

  String _currentLanguage = "uz";
  String get currentLanguage => _currentLanguage;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored != null && supportedLocales.any((l) => l.languageCode == stored)) {
      _instance._currentLanguage = stored;
      return;
    }
    final deviceLang =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (supportedLocales.any((l) => l.languageCode == deviceLang)) {
      _instance._currentLanguage = deviceLang;
    }
  }

  Future<void> setLanguage(String code) async {
    if (!supportedLocales.any((l) => l.languageCode == code)) return;
    if (code == _currentLanguage) return;
    _currentLanguage = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
  }
}

/// Map-based localization (same pattern as UyDosh's `AppStrings`/`L10n`).
class L10n {
  L10n._();

  static String get currentLanguage => LanguageState().currentLanguage;

  static String get(String key, {String? fallback}) =>
      getForLanguage(key, currentLanguage, fallback: fallback);

  static String getForLanguage(String key, String language, {String? fallback}) {
    final map = _strings[language] ?? _strings["en"]!;
    return map[key] ?? _strings["en"]![key] ?? fallback ?? key;
  }

  static const Map<String, Map<String, String>> _strings = {
    "en": {
      "app_name": "Makon 3D",
      "cancel": "Cancel",
      "done": "Done",
      "ok": "OK",
      "room_scan_title": "3D room scan",
      "room_scan_instructions":
          "Before starting the 3D scan\n\n• Turn on good lighting\n• Move slowly, avoid sudden movements\n• Hold your phone at chest level\n• Scan walls, corners, windows, and doors in each room\n• Tap Scan Other Rooms to capture additional rooms (iOS 17+)\n• Tap Finish when all rooms are scanned\n\nTotal area is the sum of all scanned room floors",
      "room_scan_start": "Start scan",
      "room_scan_finish": "Finish",
      "room_scan_scan_other_rooms": "Scan Other Rooms",
      "room_scan_uploading": "Uploading & converting…\nThis can take a few minutes.",
      "room_scan_success": "3D scan saved",
      "room_scan_cancelled": "No scan was captured. Tap Start to try again.",
      "room_scan_error": "Could not save scan. Try again.",
      "room_scan_too_large":
          "3D scan is too large to upload. Please try scanning a smaller area.",
      "room_scan_not_supported":
          "3D room scan requires an iPhone or iPad with LiDAR.",
      "room_scan_camera_required":
          "3D scan needs camera access. If you chose Don't Allow, turn on the camera for Makon 3D in Settings.",
      "room_scan_view_last": "View last scan",
      "room_3d_viewer_title": "3D",
      "room_3d_dimensions_caption": "Approximate dimensions",
      "room_3d_dimensions_line1_template":
          "Dimensions: {floorLong} × {floorShort} m",
      "room_3d_dimensions_height_template": "Height: {height} m",
      "room_3d_dimensions_line2_template": "Area: ~{floorArea} m²",
      "room_3d_load_error_title": "Could not load 3D model",
      "room_3d_floor_only_button": "Hide walls",
      "room_3d_full_room_button": "Full room",
      "room_3d_floor_only_unavailable":
          "No wall meshes were found by name in this file. Walls must be separate labeled objects in the 3D export.",
      "room_3d_zoom_in": "Zoom in",
      "room_3d_zoom_out": "Zoom out",
      "room_3d_view_mode_label": "3D view mode",
      "room_3d_view_mode_hint":
          "Switch between full room, floor with furniture, and floor only.",
      "room_3d_materials_style_label": "Materials style",
      "room_3d_materials_style_hint":
          "Toggle between real materials and stylized colors.",
      "room_3d_materials_style_value_stylized": "Stylized",
      "room_3d_materials_style_value_real": "Real",
      "room_3d_tab_view_3d": "3D",
      "room_3d_tab_floor_plan": "2D",
      "room_3d_floor_plan_reset": "Reset",
      "room_3d_floor_plan_dimensions_overall": "Overall",
      "room_3d_floor_plan_dimensions_walls": "Wall dims",
      "room_3d_floor_plan_dimensions_hide": "Hide dims",
      "room_3d_floor_plan_show_objects": "Objects",
      "room_3d_floor_plan_hide_objects": "Hide objects",
      "room_3d_floor_plan_show_grid": "Grid",
      "room_3d_floor_plan_hide_grid": "Hide grid",
      "room_3d_floor_plan_auto_align_on": "Auto-align",
      "room_3d_floor_plan_auto_align_off": "Scan angle",
      "room_3d_floor_plan_adjust_north": "North",
      "room_3d_floor_plan_adjust_north_title": "Adjust north",
      "room_3d_floor_plan_adjust_north_message":
          "Rotate if the compass does not match reality. Range ±180°.",
      "room_3d_floor_plan_adjust_north_reset": "Reset to scan",
      "room_3d_floor_plan_adjust_north_updated": "North orientation updated",
      "room_3d_floor_plan_adjust_north_degrees_format": "%+.0f°",
      "room_3d_floor_plan_edit_dimension_title": "Edit dimension",
      "room_3d_floor_plan_edit_dimension_current": "Current",
      "room_3d_floor_plan_edit_dimension_new_value": "New value (m)",
      "room_3d_floor_plan_edit_dimension_cancel": "Cancel",
      "room_3d_floor_plan_edit_dimension_apply": "Apply",
      "room_3d_floor_plan_edit_dimension_updated": "Dimension updated",
      "room_3d_floor_plan_edit_dimension_large_change_title": "Large change",
      "room_3d_floor_plan_edit_dimension_large_change_message":
          "New value differs significantly from the scanned measurement. Apply correction?",
      "room_3d_floor_plan_edit_dimension_invalid_title": "Invalid value",
      "room_3d_floor_plan_edit_dimension_invalid_message":
          "Enter a number between 0.5 and 100 meters.",
      "room_3d_floor_plan_edit_dimension_confirm_large_change": "Apply",
      "room_3d_floor_plan_unit_meters": "meters",
      "room_3d_floor_plan_object_bed": "Bed",
      "room_3d_floor_plan_object_sofa": "Sofa",
      "room_3d_floor_plan_object_table": "Table",
      "room_3d_floor_plan_object_chair": "Chair",
      "room_3d_floor_plan_object_storage": "Storage",
      "room_3d_floor_plan_object_appliance": "Appliance",
      "room_3d_floor_plan_object_cabinet": "Cabinet",
      "room_3d_floor_plan_object_television": "TV",
      "room_3d_floor_plan_object_fixture": "Fixture",
      "room_3d_floor_plan_object_unknown": "Object",
      "room_3d_sun_toggle_label": "Sunlight",
      "room_3d_sun_toggle_hint": "Show or hide sun simulation controls",
      "room_3d_sun_azimuth_label": "Azimuth",
      "room_3d_sun_elevation_label": "Elevation",
      "room_3d_sun_intensity_label": "Intensity",
      "room_3d_sun_preset_morning": "Morning",
      "room_3d_sun_preset_noon": "Noon",
      "room_3d_sun_preset_evening": "Evening",
      "room_3d_sun_azimuth_format": "Az %d°",
      "room_3d_sun_elevation_format": "El %d°",
    },
    "ru": {
      "app_name": "Makon 3D",
      "cancel": "Отмена",
      "done": "Готово",
      "ok": "ОК",
      "room_scan_title": "3D-скан комнаты",
      "room_scan_instructions":
          "Перед началом 3D-сканирования\n\n• Включите хорошее освещение\n• Двигайтесь медленно, без резких движений\n• Держите телефон на уровне груди\n• Сканируйте стены, углы, окна и двери в каждой комнате\n• Нажмите «Сканировать другие комнаты», чтобы добавить комнаты (iOS 17+)\n• Нажмите «Завершить», когда все комнаты отсканированы\n\nОбщая площадь — сумма полов всех отсканированных комнат",
      "room_scan_start": "Начать сканирование",
      "room_scan_finish": "Завершить",
      "room_scan_scan_other_rooms": "Сканировать другие комнаты",
      "room_scan_uploading": "Загрузка и конвертация…\nЭто может занять несколько минут.",
      "room_scan_success": "3D-скан сохранён",
      "room_scan_cancelled":
          "Скан не был сделан. Нажмите «Начать», чтобы попробовать снова.",
      "room_scan_error": "Не удалось сохранить скан. Попробуйте снова.",
      "room_scan_too_large":
          "3D-скан слишком большой для загрузки. Попробуйте отсканировать меньшую область.",
      "room_scan_not_supported": "3D-скан требует iPhone или iPad с LiDAR.",
      "room_scan_camera_required":
          "Для 3D-сканирования нужен доступ к камере. Если вы нажали «Запретить», включите камеру для Makon 3D в Настройках.",
      "room_scan_view_last": "Смотреть последний скан",
      "room_3d_viewer_title": "3D",
      "room_3d_dimensions_caption": "Приблизительные размеры",
      "room_3d_dimensions_line1_template":
          "Размеры: {floorLong} × {floorShort} м",
      "room_3d_dimensions_height_template": "Высота: {height} м",
      "room_3d_dimensions_line2_template": "Площадь: ~{floorArea} м²",
      "room_3d_load_error_title": "Не удалось загрузить 3D-модель",
      "room_3d_floor_only_button": "Скрыть стены",
      "room_3d_full_room_button": "Вся комната",
      "room_3d_floor_only_unavailable":
          "В файле не найдены отдельные стены по имени. В экспорте стены должны быть отдельными объектами.",
      "room_3d_zoom_in": "Приблизить",
      "room_3d_zoom_out": "Отдалить",
      "room_3d_view_mode_label": "Режим 3D-просмотра",
      "room_3d_view_mode_hint":
          "Переключайте: вся комната, пол с мебелью или только пол.",
      "room_3d_materials_style_label": "Стиль материалов",
      "room_3d_materials_style_hint":
          "Переключайте между реальными материалами и стилизованными цветами.",
      "room_3d_materials_style_value_stylized": "Стилизованный",
      "room_3d_materials_style_value_real": "Реальный",
      "room_3d_tab_view_3d": "3D",
      "room_3d_tab_floor_plan": "2D",
      "room_3d_floor_plan_reset": "Сброс",
      "room_3d_floor_plan_dimensions_overall": "Общие",
      "room_3d_floor_plan_dimensions_walls": "Стены",
      "room_3d_floor_plan_dimensions_hide": "Скрыть",
      "room_3d_floor_plan_show_objects": "Объекты",
      "room_3d_floor_plan_hide_objects": "Скрыть объекты",
      "room_3d_floor_plan_show_grid": "Сетка",
      "room_3d_floor_plan_hide_grid": "Скрыть сетку",
      "room_3d_floor_plan_auto_align_on": "Выравнивание",
      "room_3d_floor_plan_auto_align_off": "Угол скана",
      "room_3d_floor_plan_adjust_north": "Север",
      "room_3d_floor_plan_adjust_north_title": "Настроить север",
      "room_3d_floor_plan_adjust_north_message":
          "Поверните, если компас не совпадает с реальностью. Диапазон ±180°.",
      "room_3d_floor_plan_adjust_north_reset": "Сбросить к скану",
      "room_3d_floor_plan_adjust_north_updated": "Ориентация севера обновлена",
      "room_3d_floor_plan_adjust_north_degrees_format": "%+.0f°",
      "room_3d_floor_plan_edit_dimension_title": "Изменить размер",
      "room_3d_floor_plan_edit_dimension_current": "Текущее",
      "room_3d_floor_plan_edit_dimension_new_value": "Новое значение (м)",
      "room_3d_floor_plan_edit_dimension_cancel": "Отмена",
      "room_3d_floor_plan_edit_dimension_apply": "Применить",
      "room_3d_floor_plan_edit_dimension_updated": "Размер обновлён",
      "room_3d_floor_plan_edit_dimension_large_change_title":
          "Большое изменение",
      "room_3d_floor_plan_edit_dimension_large_change_message":
          "Новое значение сильно отличается от результата сканирования. Применить исправление?",
      "room_3d_floor_plan_edit_dimension_invalid_title": "Неверное значение",
      "room_3d_floor_plan_edit_dimension_invalid_message":
          "Введите число от 0,5 до 100 метров.",
      "room_3d_floor_plan_edit_dimension_confirm_large_change": "Применить",
      "room_3d_floor_plan_unit_meters": "метры",
      "room_3d_floor_plan_object_bed": "Кровать",
      "room_3d_floor_plan_object_sofa": "Диван",
      "room_3d_floor_plan_object_table": "Стол",
      "room_3d_floor_plan_object_chair": "Стул",
      "room_3d_floor_plan_object_storage": "Хранение",
      "room_3d_floor_plan_object_appliance": "Техника",
      "room_3d_floor_plan_object_cabinet": "Шкаф",
      "room_3d_floor_plan_object_television": "ТВ",
      "room_3d_floor_plan_object_fixture": "Сантехника",
      "room_3d_floor_plan_object_unknown": "Объект",
      "room_3d_sun_toggle_label": "Солнечный свет",
      "room_3d_sun_toggle_hint": "Показать или скрыть симуляцию солнца",
      "room_3d_sun_azimuth_label": "Азимут",
      "room_3d_sun_elevation_label": "Высота",
      "room_3d_sun_intensity_label": "Яркость",
      "room_3d_sun_preset_morning": "Утро",
      "room_3d_sun_preset_noon": "Полдень",
      "room_3d_sun_preset_evening": "Вечер",
      "room_3d_sun_azimuth_format": "Аз %d°",
      "room_3d_sun_elevation_format": "Выс %d°",
    },
    "uz": {
      "app_name": "Makon 3D",
      "cancel": "Bekor qilish",
      "done": "Tayyor",
      "ok": "OK",
      "room_scan_title": "3D xona skani",
      "room_scan_instructions":
          "3D skanlashni boshlashdan oldin\n\n• Yaxshi yoritishni yoqing\n• Sekin harakat qiling, keskin harakatlarsiz\n• Telefonni ko‘krak balandligida ushlang\n• Har bir xonada devorlar, burchaklar, derazalar va eshiklarni skanerlang\n• Qo'shimcha xonalar uchun «Boshqa xonalarni skanerlash»ni bosing (iOS 17+)\n• Barcha xonalar skanerlangach «Yakunlash»ni bosing\n\nUmumiy maydon — barcha skanerlangan xona pollarining yig'indisi",
      "room_scan_start": "Skanlashni boshlash",
      "room_scan_finish": "Yakunlash",
      "room_scan_scan_other_rooms": "Boshqa xonalarni skanerlash",
      "room_scan_uploading": "Yuklash va konvertatsiya…\nBu bir necha daqiqa olishi mumkin.",
      "room_scan_success": "3D skan saqlandi",
      "room_scan_cancelled":
          "Skan qilinmadi. Qayta urinish uchun «Boshlash»ni bosing.",
      "room_scan_error": "Skanni saqlab bo'lmadi. Qayta urinib ko'ring.",
      "room_scan_too_large":
          "3D skan yuklash uchun juda katta. Iltimos, kichikroq hududni skanerlab ko'ring.",
      "room_scan_not_supported":
          "3D skan uchun LiDARli iPhone yoki iPad kerak.",
      "room_scan_camera_required":
          "3D skan uchun kamera ruxsati kerak. «Ruxsat bermaslik»ni tanlasangiz, Sozlamalarda Makon 3D uchun kamerani yoqing.",
      "room_scan_view_last": "Oxirgi skanni ko'rish",
      "room_3d_viewer_title": "3D",
      "room_3d_dimensions_caption": "Taxminiy o'lchamlar",
      "room_3d_dimensions_line1_template":
          "O'lchamlar: {floorLong} x {floorShort} м",
      "room_3d_dimensions_height_template": "Balandlik: {height} м",
      "room_3d_dimensions_line2_template": "Maydon: ~{floorArea} м²",
      "room_3d_load_error_title": "3D modelni yuklab bo'lmadi",
      "room_3d_floor_only_button": "Devorlarni yashirish",
      "room_3d_full_room_button": "Butun xona",
      "room_3d_floor_only_unavailable":
          "Bu faylda devorlar nomi bo'yicha topilmadi. 3D eksportda devorlar alohida obyektlar bo'lishi kerak.",
      "room_3d_zoom_in": "Yaqinlashtirish",
      "room_3d_zoom_out": "Uzoqlashtirish",
      "room_3d_view_mode_label": "3D ko'rish rejimi",
      "room_3d_view_mode_hint":
          "Butun xona, pol va mebel yoki faqat pol rejimiga o'ting.",
      "room_3d_materials_style_label": "Materiallar uslubi",
      "room_3d_materials_style_hint":
          "Haqiqiy materiallar va uslubiy ranglar orasida almashtiring.",
      "room_3d_materials_style_value_stylized": "Uslubiy",
      "room_3d_materials_style_value_real": "Haqiqiy",
      "room_3d_tab_view_3d": "3D",
      "room_3d_tab_floor_plan": "2D",
      "room_3d_floor_plan_reset": "Tiklash",
      "room_3d_floor_plan_dimensions_overall": "Umumiy",
      "room_3d_floor_plan_dimensions_walls": "Devorlar",
      "room_3d_floor_plan_dimensions_hide": "Yashirish",
      "room_3d_floor_plan_show_objects": "Buyumlar",
      "room_3d_floor_plan_hide_objects": "Buyumlarni yashirish",
      "room_3d_floor_plan_show_grid": "To'r",
      "room_3d_floor_plan_hide_grid": "To'rni yashirish",
      "room_3d_floor_plan_auto_align_on": "Tekislash",
      "room_3d_floor_plan_auto_align_off": "Skan burchagi",
      "room_3d_floor_plan_adjust_north": "Shimol",
      "room_3d_floor_plan_adjust_north_title": "Shimolni sozlash",
      "room_3d_floor_plan_adjust_north_message":
          "Kompas haqiqatga mos kelmasa, aylantiring. Oraliq ±180°.",
      "room_3d_floor_plan_adjust_north_reset": "Skanga qaytarish",
      "room_3d_floor_plan_adjust_north_updated": "Shimol yo'nalishi yangilandi",
      "room_3d_floor_plan_adjust_north_degrees_format": "%+.0f°",
      "room_3d_floor_plan_edit_dimension_title": "O'lchamni tahrirlash",
      "room_3d_floor_plan_edit_dimension_current": "Joriy",
      "room_3d_floor_plan_edit_dimension_new_value": "Yangi qiymat (m)",
      "room_3d_floor_plan_edit_dimension_cancel": "Bekor qilish",
      "room_3d_floor_plan_edit_dimension_apply": "Qo'llash",
      "room_3d_floor_plan_edit_dimension_updated": "O'lcham yangilandi",
      "room_3d_floor_plan_edit_dimension_large_change_title": "Katta o'zgarish",
      "room_3d_floor_plan_edit_dimension_large_change_message":
          "Yangi qiymat skan natijasidan sezilarli darajada farq qiladi. Tuzatishni qo'llash?",
      "room_3d_floor_plan_edit_dimension_invalid_title": "Noto'g'ri qiymat",
      "room_3d_floor_plan_edit_dimension_invalid_message":
          "0,5 dan 100 metrgacha bo'lgan son kiriting.",
      "room_3d_floor_plan_edit_dimension_confirm_large_change": "Qo'llash",
      "room_3d_floor_plan_unit_meters": "metr",
      "room_3d_floor_plan_object_bed": "Karavot",
      "room_3d_floor_plan_object_sofa": "Divan",
      "room_3d_floor_plan_object_table": "Stol",
      "room_3d_floor_plan_object_chair": "Stul",
      "room_3d_floor_plan_object_storage": "Saqlash",
      "room_3d_floor_plan_object_appliance": "Maishiy texnika",
      "room_3d_floor_plan_object_cabinet": "Shkaf",
      "room_3d_floor_plan_object_television": "TV",
      "room_3d_floor_plan_object_fixture": "Sanitar jihoz",
      "room_3d_floor_plan_object_unknown": "Buyum",
      "room_3d_sun_toggle_label": "Quyosh nuri",
      "room_3d_sun_toggle_hint":
          "Quyosh simulyatsiyasi boshqaruvlarini ko'rsatish/yashirish",
      "room_3d_sun_azimuth_label": "Azimut",
      "room_3d_sun_elevation_label": "Balandlik",
      "room_3d_sun_intensity_label": "Yorqinlik",
      "room_3d_sun_preset_morning": "Ertalab",
      "room_3d_sun_preset_noon": "Tush",
      "room_3d_sun_preset_evening": "Kechqurun",
      "room_3d_sun_azimuth_format": "Az %d°",
      "room_3d_sun_elevation_format": "Bl %d°",
    },
  };
}
