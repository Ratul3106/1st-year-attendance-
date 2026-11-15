# Android Build & Environment Specification

This document details the environment requirements, toolchain versions, configuration baseline, and build procedures for the Android application in the Student Attendance System.

---

## 1. Toolchain & Environment Requirements

| Component | Required Version | Notes / Verified Path |
| :--- | :--- | :--- |
| **Flutter SDK** | `3.47.x` – `3.50.0` | Dart 3.13.x |
| **Java Development Kit (JDK)** | **Java 17** (LTS) | Eclipse Adoptium Temurin 17 (`C:\Program Files\Eclipse Adoptium\jdk-17.0.21.9-hotspot`) |
| **Android SDK** | API Level 34 (`Android 14`) | Platforms `android-34`, Build-Tools `34.0.0` |
| **Gradle** | `8.14.3` | Configured via Gradle Wrapper |
| **Android Gradle Plugin (AGP)** | `8.11.1` | Configured in `android/settings.gradle` |
| **Kotlin Gradle Plugin (KGP)** | `2.2.20` | Configured in `android/settings.gradle` |
| **Firebase Services Plugin** | `4.4.0` | Google Services plugin |

---

## 2. Configuration Baseline

The Android project is configured under the following stable baseline:

### A. Gradle Wrapper (`android/gradle/wrapper/gradle-wrapper.properties`)
```properties
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.14.3-all.zip
```

### B. Root Settings (`android/settings.gradle`)
```groovy
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.11.1" apply false
    id "org.jetbrains.kotlin.android" version "2.2.20" apply false
    id "com.google.gms.google-services" version "4.4.0" apply false
}
```

### C. App Build Configuration (`android/app/build.gradle`)
- **Compile SDK**: `34`
- **Target SDK**: `34`
- **Min SDK**: `flutter.minSdkVersion` (21+)
- **JVM Target**: Java 17 compatibility (`JavaVersion.VERSION_17`, `kotlinOptions { jvmTarget = '17' }`)
- **Firebase Analytics**: Preserved via Firebase BOM (`32.7.2`)

### D. Gradle Properties (`android/gradle.properties`)
```properties
android.builtInKotlin=false
android.newDsl=false
```

---

## 3. Build Instructions

### Release APK Build Command

Before executing the build, ensure that `JAVA_HOME` explicitly points to JDK 17:

#### PowerShell (Windows):
```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.21.9-hotspot"
$env:PATH = "$env:JAVA_HOME\bin;" + $env:PATH

# Clean build artifacts
flutter clean
flutter pub get

# Build Release APK
flutter build apk --release
```

#### Bash (macOS / Linux):
```bash
export JAVA_HOME="/path/to/jdk-17"
export PATH="$JAVA_HOME/bin:$PATH"

flutter clean
flutter pub get
flutter build apk --release
```

### Expected Output Location
When the release build completes successfully, the resulting APK is located at:
```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## 4. Controlled AGP 9 / Gradle 9.5 Evaluation Summary

A controlled trial migration to **Gradle 9.5.0** and **Android Gradle Plugin 9.3.1** with AGP built-in Kotlin (`android.builtInKotlin=true`) was conducted in November 2026. The findings from this trial are documented below:

1. **Kotlin Version Gate**: AGP 9.3.1's built-in Kotlin embeds Kotlin **2.2.10**. However, the Flutter Gradle Plugin enforces a strict minimum requirement of Kotlin $\ge$ **2.2.20**, triggering a build failure at plugin application time unless `--android-skip-build-dependency-validation` is specified.
2. **NDK 28 Dependency**: AGP 9.3.1 requires Android NDK `28.2.13676358` for native build dependencies (`jni`, `jni_flutter`).
3. **Current Decision**: In accordance with stability best practices, the Android configuration was maintained at the fully verified **Gradle 8.14.3 / AGP 8.11.1 / Kotlin 2.2.20** baseline.

> [!NOTE]
> Physical Android device installation and end-to-end hardware testing should be performed after local device provisioning and release signing configuration.
