import 'package:flutter/foundation.dart';

import '../../../shared/utils/json_parse.dart';

@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    this.avatarUrl,
    this.avatarImagePath,
    this.dailyGoalMinutes = 45,
  });

  final String id;
  final String name;
  final String username;
  final String? email;
  final String? avatarUrl; // Network URL (gelecekte Firebase için)
  final String? avatarImagePath; // Yerel dosya yolu
  final int dailyGoalMinutes;

  UserProfile copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? avatarUrl,
    String? avatarImagePath,
    int? dailyGoalMinutes,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarImagePath: avatarImagePath ?? this.avatarImagePath,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'avatarUrl': avatarUrl,
      'avatarImagePath': avatarImagePath,
      'dailyGoalMinutes': dailyGoalMinutes,
    };
  }

  /// Tolerant deserialization (T1.3): never throws on drifted/missing fields.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: asStringOrNull(json['id']) ?? 'u1',
      name: asStringOrNull(json['name']) ?? '',
      username: asStringOrNull(json['username']) ?? '',
      email: asStringOrNull(json['email']),
      avatarUrl: asStringOrNull(json['avatarUrl']),
      avatarImagePath: asStringOrNull(json['avatarImagePath']),
      dailyGoalMinutes: asIntOr(json['dailyGoalMinutes'], 45),
    );
  }

  /// Returns null when the record can't be parsed at all (T1.3).
  static UserProfile? tryParse(Map<String, dynamic> json) {
    try {
      return UserProfile.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}

