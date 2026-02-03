# Keep Flutter and its internal classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep the Record plugin
-keep class com.llfbandit.record.** { *; }

# Keep Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Keep FFmpegKit (used by Whisper)
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.arthenica.ffmpegkit.** { *; }

# Ignore missing Play Core classes referenced by the Flutter Engine
-dontwarn com.google.android.play.core.**