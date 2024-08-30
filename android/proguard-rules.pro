# Keep all classes in your plugin's package
-keep class com.gdelataillade.alarm.** { *; }

# Keep all classes related to Gson and prevent them from being obfuscated
-keep class com.google.gson.** { *; }
-keep class sun.misc.Unsafe { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Prevent stripping of methods/fields annotated with specific annotations, if needed.
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Preserve classes that might be used in reflection or through indirect means
-keepclassmembers class **.R$* {
    <fields>;
}

# Avoid stripping enums, if your plugin uses them
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}