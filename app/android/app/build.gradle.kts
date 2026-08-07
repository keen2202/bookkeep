import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 读取签名配置 android/key.properties（CI 构建前由工作流生成；本地签名时手动放置）
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
// 四项配置齐全才启用正式签名；缺失时回退 debug 签名，保证本地/CI 无密钥也可构建
val useReleaseSigning = keystorePropertiesFile.exists() &&
    keystoreProperties["storeFile"] != null &&
    keystoreProperties["keyAlias"] != null &&
    keystoreProperties["storePassword"] != null &&
    keystoreProperties["keyPassword"] != null

android {
    namespace = "com.bookkeep.bookkeep_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.bookkeep.bookkeep_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // storeFile 用 file() 相对本模块（android/app/）解析，与 CI 解码到的 upload-keystore.jks 同目录
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as? String
            keyPassword = keystoreProperties["keyPassword"] as? String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as? String
        }
    }

    buildTypes {
        release {
            signingConfig = if (useReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // 无签名配置时回退 debug 签名（否则 AGP 会因缺 storeFile 直接构建失败）
                signingConfigs.getByName("debug")
            }
            // 审查体积：R8 全量压缩 + 资源收缩（release 专用；debug 保持快速迭代）
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
    // 审查体积 BK-R-015：分发仅含 arm ABI（移除 x86_64，模拟器仅 debug 使用；
    // 注意不得用 ndk.abiFilters——与 Flutter 插件的 splits abi 配置冲突导致构建失败）
    targetPlatforms = listOf("android-arm", "android-arm64")
}
