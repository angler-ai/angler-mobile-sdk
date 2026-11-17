pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "AnglerExample"
include(":app")

// Build the SDK from source instead of Maven.
includeBuild("../../android") {
    dependencySubstitution {
        substitute(module("ai.getangler:analytics")).using(project(":angler-analytics"))
    }
}
