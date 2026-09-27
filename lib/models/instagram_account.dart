enum AccountStatus {
  active,
  challengeRequired,
  rateLimited,
  disabled,
}

class InstagramAccount {
  final String id; // ds_user_id
  final String username;
  final String profilePicUrl;
  final Map<String, String> cookies;
  final String userAgent;
  final String? proxy;
  final AccountStatus status;
  final DateTime addedAt;
  final DateTime? lastActionAt;
  final int followsCountToday;

  InstagramAccount({
    required this.id,
    required this.username,
    this.profilePicUrl = '',
    required this.cookies,
    required this.userAgent,
    this.proxy,
    this.status = AccountStatus.active,
    DateTime? addedAt,
    this.lastActionAt,
    this.followsCountToday = 0,
  }) : addedAt = addedAt ?? DateTime.now();

  String? get sessionId => cookies['sessionid'];
  String? get csrfToken => cookies['csrftoken'];

  String get cookieHeader {
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  InstagramAccount copyWith({
    String? id,
    String? username,
    String? profilePicUrl,
    Map<String, String>? cookies,
    String? userAgent,
    String? proxy,
    AccountStatus? status,
    DateTime? addedAt,
    DateTime? lastActionAt,
    int? followsCountToday,
  }) {
    return InstagramAccount(
      id: id ?? this.id,
      username: username ?? this.username,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      cookies: cookies ?? this.cookies,
      userAgent: userAgent ?? this.userAgent,
      proxy: proxy ?? this.proxy,
      status: status ?? this.status,
      addedAt: addedAt ?? this.addedAt,
      lastActionAt: lastActionAt ?? this.lastActionAt,
      followsCountToday: followsCountToday ?? this.followsCountToday,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'profilePicUrl': profilePicUrl,
      'cookies': cookies,
      'userAgent': userAgent,
      'proxy': proxy,
      'status': status.name,
      'addedAt': addedAt.toIso8601String(),
      'lastActionAt': lastActionAt?.toIso8601String(),
      'followsCountToday': followsCountToday,
    };
  }

  factory InstagramAccount.fromJson(Map<String, dynamic> json) {
    return InstagramAccount(
      id: json['id'] as String,
      username: json['username'] as String,
      profilePicUrl: (json['profilePicUrl'] as String?) ?? '',
      cookies: Map<String, String>.from(json['cookies'] as Map),
      userAgent: json['userAgent'] as String,
      proxy: json['proxy'] as String?,
      status: AccountStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AccountStatus.active,
      ),
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastActionAt: json['lastActionAt'] != null
          ? DateTime.parse(json['lastActionAt'] as String)
          : null,
      followsCountToday: (json['followsCountToday'] as int?) ?? 0,
    );
  }
}
