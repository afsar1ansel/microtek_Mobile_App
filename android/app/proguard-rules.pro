# Flutter-specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Suppress warnings for missing classes
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy

# Keep Play Core classes
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }

# Suppress warnings for Play Core
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**

-keep class com.signify.hue.** { *; }
-keep class com.lib.flutter_blue_plus.* { *; }
-keep class com.microtek.eyetracker.MainActivity { *; }