# WhatsApp Scheduler (personal use)

This Flutter sample opens WhatsApp to a group invite link with your message once the device is unlocked after a scheduled time. It requests notification permissions so you get a reminder on iOS.

## Running
1. Install Flutter (3.19 or newer) and run `flutter pub get`.
2. Run on iOS from Xcode or `flutter run`.
3. Enter your WhatsApp group invite link, a message, and schedule a time. Keep the device unlocked near the scheduled moment.

> iOS cannot automatically tap "Send" for you. The app opens WhatsApp with the pre-filled text, and you must confirm sending.

### Android build note
`flutter_local_notifications` requires Java 8 desugaring on Android. If you run the sample on Android, enable desugaring in `android/app/build.gradle`:

```groovy
android {
  compileOptions {
    sourceCompatibility JavaVersion.VERSION_1_8
    targetCompatibility JavaVersion.VERSION_1_8
    coreLibraryDesugaringEnabled true
  }
}

dependencies {
  // ...
  coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```
