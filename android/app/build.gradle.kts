import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// امضای release: android/key.properties (در git نیست؛ نمونه: key.properties.example).
// اگر نباشد، release با کلید debug امضا می‌شود تا ساخت محلی نشکند — برای انتشار نه.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "ir.calorielens.calorie_lens"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // لازم برای flutter_local_notifications (یادآورهای زمان‌بندی‌شده)
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // شناسه‌ی نهایی پیش از انتشار تعیین می‌شود (بخش ۱۴).
        applicationId = "ir.calorielens.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // بخش ۱۱: حداقل اندروید 7.0
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // دو فروشگاه: کافه‌بازار و مایکت (بخش ۹-۳).
    flavorDimensions += "store"
    productFlavors {
        create("bazaar") {
            dimension = "store"
            resValue("string", "app_name", "کالری‌لنز")
        }
        create("myket") {
            dimension = "store"
            resValue("string", "app_name", "کالری‌لنز")
        }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // یک کلید برای هر دو فروشگاه؛ گم شدنش یعنی دیگر نمی‌شود به‌روزرسانی داد.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
