allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    // Some plugins still pin an older compileSdk than their own transitive
    // dependencies demand (file_picker sits at 34 while
    // flutter_plugin_android_lifecycle requires 36), and Gradle fails the
    // build rather than picking the higher one. Raising compileSdk only
    // widens the APIs a library may compile against; it does not touch minSdk
    // or targetSdk, so neither runtime behaviour nor device compatibility
    // changes here.
    //
    // This must be registered BEFORE evaluationDependsOn below: that call
    // evaluates the project, and afterEvaluate throws once that has happened.
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android is com.android.build.gradle.BaseExtension) {
            android.compileSdkVersion(36)
        }
    }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
