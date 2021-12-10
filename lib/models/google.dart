class Google {
  late String appId;
  late String banner;
  late String interstitial;
  late String rewarded;
  final String sdk = 'com.google.android.gms:play-services-ads:';
  late String sdkVersion;

  Google(
      {required this.appId,
      required this.sdkVersion,
      required this.banner,
      required this.interstitial,
      required this.rewarded});

  Google.fromJson(Map<String, dynamic> json) {
    appId = json['appId'];
    banner = json['banner'];
    interstitial = json['interstitial'];
    rewarded = json['rewarded'];
    sdkVersion = json['sdkVersion'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['appId'] = this.appId;
    data['banner'] = this.banner;
    data['interstitial'] = this.interstitial;
    data['rewarded'] = this.rewarded;
    data['sdkVersion'] = this.sdkVersion;
    return data;
  }
}
