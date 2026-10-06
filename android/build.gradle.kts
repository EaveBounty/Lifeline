allprojects {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
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

// 统一所有插件子模块的 compileSdk，避免个别插件固定旧版本导致 AAR 元数据校验失败。
gradle.projectsEvaluated {
    subprojects.forEach { sub ->
        val androidExt = sub.extensions.findByName("android") ?: return@forEach
        try {
            androidExt.javaClass
                .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                .invoke(androidExt, 36)
        } catch (_: Throwable) {
            try {
                androidExt.javaClass
                    .getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                    .invoke(androidExt, 36)
            } catch (_: Throwable) {
                // 忽略：部分扩展无此方法
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
