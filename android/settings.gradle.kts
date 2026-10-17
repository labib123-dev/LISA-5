pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // 🔧 ফিক্স ১: AGP 8.9.1 → 8.11.1 (Flutter-এর minimum, আর CI-টেস্টেড)
    id("com.android.application") version "8.11.1" apply false

    // 🔧 ফিক্স ২: Kotlin 2.1.0 → 2.2.20
    //    (AGP 8.11.1-এর সাথে যেটাই Flutter CI-তে টেস্ট করা)
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
