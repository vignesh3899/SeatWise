import 'package:equatable/equatable.dart';

/// Domain representation of an authenticated user, decoupled from FirebaseAuth's
/// `User` so the rest of the app never depends on the Firebase SDK types.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.preferShade = true,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;

  /// User preference: when true the engine biases toward the shaded side.
  final bool preferShade;

  final DateTime? createdAt;

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    bool? preferShade,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      preferShade: preferShade ?? this.preferShade,
      createdAt: createdAt,
    );
  }

  factory AppUser.fromJson(String uid, Map<String, dynamic> json) => AppUser(
        uid: uid,
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String?,
        photoUrl: json['photoUrl'] as String?,
        preferShade: json['preferShade'] as bool? ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'preferShade': preferShade,
        'createdAt': (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
      };

  @override
  List<Object?> get props => [uid, email, displayName, photoUrl, preferShade];
}
