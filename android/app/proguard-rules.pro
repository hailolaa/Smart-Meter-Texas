# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep json model reflection (defensive)
-keepattributes Signature
-keepattributes *Annotation*
