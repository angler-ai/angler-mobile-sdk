import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

fun prop(name: String, default: String) = (findProperty(name) as String?) ?: default

android {
    namespace = "ai.getangler.example"
    compileSdk = 35

    defaultConfig {
        applicationId = "ai.getangler.example"
        minSdk = 21
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        buildConfigField("String", "ANGLER_WORKSPACE_ID", "\"${prop("anglerWorkspaceId", "example-workspace")}\"")
        buildConfigField("String", "ANGLER_TOKEN", "\"${prop("anglerToken", "replace-me")}\"")
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

dependencies {
    implementation("ai.getangler:analytics:0.1.0")
}
