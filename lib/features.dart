/// Build-time switches. Example: flutter build appbundle --dart-define=LOANS_ENABLED=false
///
/// Loans are off in the Google Play build until MOM has an FCCPC digital-lending approval letter
/// (Google Play requires it for personal-loan apps in Nigeria). The test APK keeps them on.
const loansEnabled = bool.fromEnvironment('LOANS_ENABLED', defaultValue: true);
