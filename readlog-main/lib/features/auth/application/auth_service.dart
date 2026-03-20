import 'package:flutter_riverpod/flutter_riverpod.dart';

class User {
  final String id;
  const User({required this.id});
}

class AuthService {
  User? get user => const User(id: 'test_user');
}

final authProvider = Provider<AuthService>((ref) {
  return AuthService();
});
