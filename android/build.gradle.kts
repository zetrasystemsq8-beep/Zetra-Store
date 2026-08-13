allprojects {
    repositories {
        // ✅ PRIORITY REORDERED: Google Maven first (most reliable in CI/CD)
        google()
        
        // ✅ Gradle Plugin Portal as secondary for plugin dependencies
        gradlePluginPortal()
        
        // ✅ Maven Central as tertiary fallback
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
