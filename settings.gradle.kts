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
        // Tapsell / Adivery SDK repositories are added here when the ad adapters are wired (step 4).
    }
}

rootProject.name = "Hesabyar"
include(":app", ":domain")
