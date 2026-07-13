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

// file_picker 等插件默认 compileSdk 34，与 flutter_plugin_android_lifecycle(要求 36+) 冲突。
// evaluationDependsOn(":app") 会使部分子项目在配置阶段已 evaluate，故需兼容两种时机。
fun Project.forceCompileSdk36() {
    val android = extensions.findByName("android") ?: return
    try {
        val setCompileSdk =
            android.javaClass.methods.firstOrNull {
                it.name == "setCompileSdk" && it.parameterTypes.size == 1
            }
        if (setCompileSdk != null) {
            setCompileSdk.invoke(android, 36)
            return
        }
        val setCompileSdkVersion =
            android.javaClass.methods.firstOrNull {
                it.name == "setCompileSdkVersion" &&
                    it.parameterTypes.size == 1 &&
                    it.parameterTypes[0] == Int::class.javaPrimitiveType
            }
        setCompileSdkVersion?.invoke(android, 36)
    } catch (_: Exception) {
        // ignore non-Android subprojects
    }
}

subprojects {
    if (state.executed) {
        forceCompileSdk36()
    } else {
        afterEvaluate { forceCompileSdk36() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
