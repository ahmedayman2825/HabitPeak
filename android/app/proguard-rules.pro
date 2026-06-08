# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter's Play Store Split Application references these, but if they are not used, ignore warnings
-dontwarn com.google.android.play.core.**

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# home_widget
-keep class es.antonborri.home_widget.** { *; }

# Keep native AppWidget and Glance classes
-keep class com.openhabit.app.MainActivity { *; }
-keep class com.openhabit.app.HabitWidgetReceiver { *; }
-keep class com.openhabit.app.HabitWidget { *; }
-keep class com.openhabit.app.QuickCompleteAction { *; }
