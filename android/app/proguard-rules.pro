## Gson / flutter_local_notifications ProGuard/R8 rules
##
## flutter_local_notifications uses Gson to serialize NotificationDetails to
## JSON before storing in AlarmManager PendingIntents. Without these keep rules
## R8 strips the generic Signature attributes, causing:
##   java.lang.RuntimeException: Missing type parameter.
## inside ScheduledNotificationReceiver.onReceive() at release time.
##
## Source: flutter_local_notifications example app proguard-rules.pro
##   ~/.pub-cache/.../flutter_local_notifications-17.2.4/example/android/app/proguard-rules.pro

# Gson uses generic type information stored in a class file when working with
# fields. R8 removes such information by default, so keep all Signature attrs.
-keepattributes Signature

# Keep annotation attributes (required for @Expose and @SerializedName)
-keepattributes *Annotation*

# Gson specific classes
-dontwarn sun.misc.**

# Prevent R8 from stripping interface information from TypeAdapter,
# TypeAdapterFactory, JsonSerializer, JsonDeserializer instances
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent R8 from leaving Data object members always null
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Retain generic signatures of TypeToken and its subclasses with R8 version
# 3.0 and higher. This is the critical rule that fixes "Missing type parameter."
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Keep all flutter_local_notifications model classes used by Gson deserialization
# in ScheduledNotificationReceiver (runs in a BroadcastReceiver context, not in
# the Flutter engine, so these must survive R8 shrinking)
-keep class com.dexterous.flutterlocalnotifications.** { *; }
