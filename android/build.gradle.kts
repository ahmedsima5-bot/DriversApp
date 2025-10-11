// يجب أن يكون هذا السطر في أعلى الملف ليتمكن التطبيق من قراءة تهيئة Firebase
apply plugin: 'com.google.gms.google-services'

def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterRoot = localProperties.getProperty('flutter.sdk')
if (flutterRoot == null) {
    throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
}

// Check for the existence of the flutter.gradle file
if (!file("$flutterRoot/packages/flutter_tools/gradle/flutter.gradle").exists()) {
    throw new GradleException("Cannot find flutter.gradle script at $flutterRoot/packages/flutter_tools/gradle/flutter.gradle")
}

apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"

android {
    namespace "com.example.drivers"
    compileSdk 34 // تأكد من استخدام إصدار SDK حديث

    defaultConfig {
        // TODO: Specify your own unique Application ID (e.g. com.example.my_app).
        applicationId "com.example.drivers"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode flutter.versionCode.toInteger()
        versionName flutter.versionName
        multiDexEnabled true // غالبا ما تكون مطلوبة مع Firebase و Google Services الكبيرة
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig signingConfigs.debug
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
    // إضافة Firebase BoM (مكتبة إدارة الإصدارات)
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    
    // إضافة مكتبة Google Play Services لمنع الأخطاء في بعض الأجهزة
    implementation 'com.google.android.gms:play-services-base:18.2.0'

    // يجب إضافة Firebase Core هنا لدعم تهيئة Firebase (سواء باستخدام google-services.json أو firebase_options.dart)
    implementation 'com.google.firebase:firebase-core'
}
