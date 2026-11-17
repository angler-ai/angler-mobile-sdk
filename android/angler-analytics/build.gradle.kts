import com.vanniktech.maven.publish.SonatypeHost
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("com.vanniktech.maven.publish")
}

group = property("GROUP") as String
version = property("VERSION_NAME") as String

android {
    namespace = "ai.getangler.analytics"
    compileSdk = 35

    defaultConfig {
        minSdk = 21
        consumerProguardFiles("consumer-rules.pro")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    testOptions {
        targetSdk = 35
        unitTests.isIncludeAndroidResources = true
    }

    lint {
        targetSdk = 35
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

dependencies {
    implementation("com.android.installreferrer:installreferrer:2.2")
    implementation("com.google.android.gms:play-services-ads-identifier:18.1.0")
    implementation("androidx.lifecycle:lifecycle-process:2.8.7")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.14.1")
    testImplementation("org.json:json:20240303")
    testImplementation("androidx.test:core:1.6.1")
}

tasks.withType<Test>().configureEach {
    systemProperty("anglerFixturesDir", rootProject.file("../spec/fixtures").absolutePath)
}

// Published to Maven Central (Central Portal) as ai.getangler:analytics. Signing uses the
// ORG_GRADLE_PROJECT_signingInMemoryKey / ...KeyPassword env vars in the release workflow; local
// publishToMavenLocal runs unsigned.
mavenPublishing {
    publishToMavenCentral(SonatypeHost.CENTRAL_PORTAL, automaticRelease = true)
    if (providers.gradleProperty("signingInMemoryKey").isPresent) signAllPublications()
    coordinates("ai.getangler", "analytics", version.toString())

    pom {
        name.set("Angler Analytics")
        description.set("Angler app events and ad-attribution signals for Android (Kotlin and Java).")
        url.set("https://github.com/angler-ai/angler-mobile-sdk")
        licenses {
            license {
                name.set("MIT License")
                url.set("https://opensource.org/licenses/MIT")
            }
        }
        developers {
            developer {
                id.set("angler-ai")
                name.set("Angler AI")
                url.set("https://getangler.ai")
            }
        }
        scm {
            url.set("https://github.com/angler-ai/angler-mobile-sdk")
            connection.set("scm:git:https://github.com/angler-ai/angler-mobile-sdk.git")
            developerConnection.set("scm:git:ssh://git@github.com/angler-ai/angler-mobile-sdk.git")
        }
    }
}
