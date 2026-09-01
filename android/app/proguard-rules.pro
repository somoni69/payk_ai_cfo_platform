# Flutter Wrapper & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Local Auth / Biometrics
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# Security Crypto / EncryptedSharedPreferences
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# Preserving Annotations & Signatures for Serialization/Reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
