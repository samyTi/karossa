# ML Kit Text Recognition - Keep missing classes
# These classes are referenced by google_mlkit_text_recognition but may be missing
# for Chinese, Japanese, Korean, and Devanagari language support

# Keep all ML Kit text recognition classes
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }

# Keep Google ML Kit common classes
-keep class com.google.mlkit.common.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Flutter plugin classes
-keep class io.flutter.plugin.** { *; }
-keep class com.google.mlkit_commons.** { *; }

# Suppress warnings about missing classes
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.**