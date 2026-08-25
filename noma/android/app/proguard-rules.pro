# WorkManager ProGuard Rules (Prevents crash on release build due to WorkDatabase_Impl reflection stripping)
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}

# Flutter Engine ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core dontwarn rules for Flutter engine deferred components
-dontwarn com.google.android.play.core.**

# SQLite & Drift ProGuard Rules
-keep class com.simonbinder.sqlite3.** { *; }
-keep class io.simonbinder.sqlite3.** { *; }
-dontwarn sqlite3.**
