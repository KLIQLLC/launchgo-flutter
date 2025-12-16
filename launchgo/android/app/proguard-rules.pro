# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# Google Play Core (for split APKs)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Keep Google Sign-In classes
-keep public class com.google.android.gms.auth.api.signin.** { *; }
-keep public class com.google.android.gms.auth.api.Auth { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Retrofit and OkHttp (if you're using them)
-keepattributes Signature
-keepattributes *Annotation*
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**

# Keep all model classes (adjust package name as needed)
-keep class com.launchgo.** { *; }
-keep class launchgo.** { *; }

# Flutter CallKit Incoming
-keep class com.hiennv.flutter_callkit_incoming.** { *; }