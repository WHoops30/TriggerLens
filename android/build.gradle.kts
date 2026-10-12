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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Custom script to dynamically fix older plugins (Namespace AND CompileSDK)
subprojects {
    val fixAndroidPlugins = Action<Project> {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                // 1. Fix missing Namespaces
                val currentNamespace = androidExt.javaClass.getMethod("getNamespace").invoke(androidExt)
                if (currentNamespace == null) {
                    androidExt.javaClass.getMethod("setNamespace", String::class.java).invoke(androidExt, group.toString())
                }
            } catch (e: Exception) {}

            try {
                // 2. Force Compile SDK to 34 for ALL stubborn plugins
                androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.java).invoke(androidExt, 36)
            } catch (e: Exception) {}
        }
    }
    
    // Safely execute to prevent the "already evaluated" crash
    if (state.executed) {
        fixAndroidPlugins.execute(this)
    } else {
        afterEvaluate(fixAndroidPlugins)
    }
}