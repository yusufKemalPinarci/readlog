import 'package:flutter/foundation.dart';

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

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      avatarImagePath: json['avatarImagePath'] as String?,
      dailyGoalMinutes: json['dailyGoalMinutes'] as int? ?? 45,
    );
  }
}

