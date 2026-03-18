import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Fully local folder service — no server calls.
/// Folders are stored in SharedPreferences as JSON.
/// Password→folder assignments are stored as a separate JSON map.
class FolderService {
  static const _foldersKey = 'local_folders';
  static const _nextIdKey = 'local_folder_next_id';
  static const _folderMapKey = 'password_folder_map';

  // ── Folder CRUD ─────────────────────────────────────────────────────────────

  /// Returns all folders with an added [password_count] field.
  /// Pass [includeHidden] = true to also include hidden folders.
  static Future<List<Map<String, dynamic>>> getFolders({
    bool includeHidden = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_foldersKey) ?? '[]';
    final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();

    // Compute per-folder password counts from the assignment map.
    final mapRaw = prefs.getString(_folderMapKey) ?? '{}';
    final folderMap = Map<String, dynamic>.from(json.decode(mapRaw));
    final counts = <int, int>{};
    for (final v in folderMap.values) {
      if (v != null) {
        final id = v as int;
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }

    final result = list.map<Map<String, dynamic>>((f) {
      final id = f['id'] as int;
      return {...f, 'password_count': counts[id] ?? 0};
    }).toList();

    if (!includeHidden) {
      return result.where((f) => !(f['is_hidden'] as bool? ?? false)).toList();
    }
    return result;
  }

  /// Creates a new folder locally and returns its map.
  static Future<Map<String, dynamic>?> createFolder({
    required String name,
    required String color,
    required String icon,
    bool isHidden = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final nextId = prefs.getInt(_nextIdKey) ?? 1;
    final raw = prefs.getString(_foldersKey) ?? '[]';
    final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();

    final folder = <String, dynamic>{
      'id': nextId,
      'name': name,
      'color': color,
      'icon': icon,
      'is_hidden': isHidden,
      'password_count': 0,
    };
    list.add(folder);
    await prefs.setString(_foldersKey, json.encode(list));
    await prefs.setInt(_nextIdKey, nextId + 1);
    return folder;
  }

  /// Updates an existing folder. Returns updated map or null if not found.
  static Future<Map<String, dynamic>?> updateFolder(
    int folderId, {
    String? name,
    String? color,
    String? icon,
    bool? isHidden,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_foldersKey) ?? '[]';
    final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();

    final idx = list.indexWhere((f) => f['id'] == folderId);
    if (idx == -1) return null;

    if (name != null) list[idx]['name'] = name;
    if (color != null) list[idx]['color'] = color;
    if (icon != null) list[idx]['icon'] = icon;
    if (isHidden != null) list[idx]['is_hidden'] = isHidden;

    await prefs.setString(_foldersKey, json.encode(list));
    return list[idx];
  }

  /// Deletes a folder and clears all password→folder assignments to it.
  static Future<bool> deleteFolder(int folderId) async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_foldersKey) ?? '[]';
    final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
    list.removeWhere((f) => f['id'] == folderId);
    await prefs.setString(_foldersKey, json.encode(list));

    // Remove all password assignments pointing to this folder.
    final mapRaw = prefs.getString(_folderMapKey) ?? '{}';
    final map = Map<String, dynamic>.from(json.decode(mapRaw));
    map.removeWhere((_, v) => v == folderId);
    await prefs.setString(_folderMapKey, json.encode(map));

    return true;
  }

  // ── Password ↔ folder assignment ────────────────────────────────────────────

  /// Returns the locally assigned folder ID for [passwordId], or null.
  static Future<int?> getFolderForPassword(int passwordId) async {
    final prefs = await SharedPreferences.getInstance();
    final mapRaw = prefs.getString(_folderMapKey) ?? '{}';
    final map = Map<String, dynamic>.from(json.decode(mapRaw));
    final v = map[passwordId.toString()];
    return v as int?;
  }

  /// Assigns [passwordId] to [folderId] (pass null to remove from any folder).
  static Future<void> setFolderForPassword(int passwordId, int? folderId) async {
    final prefs = await SharedPreferences.getInstance();
    final mapRaw = prefs.getString(_folderMapKey) ?? '{}';
    final map = Map<String, dynamic>.from(json.decode(mapRaw));
    if (folderId == null) {
      map.remove(passwordId.toString());
    } else {
      map[passwordId.toString()] = folderId;
    }
    await prefs.setString(_folderMapKey, json.encode(map));
  }

  /// Returns a map of passwordId → folderId for all assigned passwords.
  static Future<Map<int, int>> getAllFolderMappings() async {
    final prefs = await SharedPreferences.getInstance();
    final mapRaw = prefs.getString(_folderMapKey) ?? '{}';
    final map = Map<String, dynamic>.from(json.decode(mapRaw));
    final result = <int, int>{};
    for (final entry in map.entries) {
      if (entry.value != null) {
        result[int.parse(entry.key)] = entry.value as int;
      }
    }
    return result;
  }
}
