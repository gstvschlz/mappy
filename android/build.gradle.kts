allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("${project(":flutter_background_geolocation").projectDir}/libs")
        }
    }
}

ext {
    set("compileSdkVersion", 36)
    set("targetSdkVersion", 34)
    set("appCompatVersion", "1.6.1")
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    afterEvaluate {
        if (extensions.findByName("android") != null) {
            extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                compileSdkVersion(36)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
