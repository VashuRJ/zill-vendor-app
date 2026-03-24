# =============================================================================
# Zill Restaurant Partner — ProGuard / R8 Rules
# Applied only to release builds (isMinifyEnabled = true in build.gradle.kts)
# =============================================================================

# ── Flutter Engine ────────────────────────────────────────────────────────────
# The Dart VM is native code; ProGuard only touches the Java/Kotlin bridge.
# Flutter's own plugin (dev.flutter.flutter-gradle-plugin) injects
# flutter_proguard_rules.pro automatically, but we keep these as belt-and-
# suspenders in case of plugin version changes.
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keepclassmembers class io.flutter.** { *; }
-dontwarn io.flutter.**

# ── App's own Java/Kotlin classes ─────────────────────────────────────────────
# Keep our custom native services so their names are preserved in crash traces.
-keep class com.zill.vendor.MainActivity { *; }
-keep class com.zill.vendor.ZillFirebaseMessagingService { *; }
-keep class com.zill.vendor.OrderAlarmService { *; }

# ── Razorpay ──────────────────────────────────────────────────────────────────
# Razorpay uses runtime reflection & native JS bridge inside a WebView.
# Stripping any class will cause silent payment failures or crashes.
-keep class com.razorpay.** { *; }
-keepclassmembers class com.razorpay.** { *; }
-keepclasseswithmembers class com.razorpay.** { *; }
-dontwarn com.razorpay.**
# Razorpay's checkout internally calls ProGuard-annotated methods
-keepattributes *Annotation*

# ── Firebase / FCM ────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keepclassmembers class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepclassmembers class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
# Google Play Core (used by Firebase App Check, Dynamic Links, etc.)
-dontwarn com.google.android.play.**

# ── OkHttp + Okio (used by Firebase internals on the Java side) ──────────────
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
-keep interface okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# ── Kotlin ────────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlin.Metadata { public <methods>; }
-keepclassmembers class **$WhenMappings { <fields>; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ── AndroidX / Jetpack ────────────────────────────────────────────────────────
-keep class androidx.** { *; }
-dontwarn androidx.**

# ── Serialization / Reflection attributes ─────────────────────────────────────
# Required for stack traces, generic type info, and annotation processing.
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ── Preserve line numbers for crash diagnostics ──────────────────────────────
# Stack traces uploaded to Firebase Crashlytics (or read from logcat) will
# reference original source lines even after minification.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ── Strip Android debug log calls from release bytecode ──────────────────────
# R8 eliminates these call-sites entirely at the bytecode level.
# Removes Log.v (verbose) and Log.d (debug) — noisy, privacy-leaking logs.
# Log.w / Log.e / Log.wtf are preserved for crash diagnosis.
# NOTE: Flutter's Dart print() / debugPrint() are handled separately —
#       the Dart compiler's --no-sound-null-safety / kReleaseMode flag
#       strips them at the Dart compilation stage, not here.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static boolean isLoggable(...);
}

# ── Suppress noisy lint warnings from transitive dependencies ────────────────
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
-dontwarn sun.misc.Unsafe
