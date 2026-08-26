plugins {
    kotlin("jvm") version "2.3.20"
}

group = "com.utopia-rise"
version = "25.0.4-ios.1"

repositories {
    mavenCentral()
}

kotlin {
    jvmToolchain(17)
}

val graalVmHome = providers.gradleProperty("graalvmHome")
    .orElse(providers.environmentVariable("GRAALVM_HOME"))

tasks.register<Exec>("generateCapCache") {
    dependsOn(tasks.build)
    group = "graal-ios"

    val nativeImage = graalVmHome.map { File(it).resolve("bin").resolve("native-image") }
    val capCacheDirectory = layout.buildDirectory.dir("cap-cache")
    val dummyJarFile = tasks.jar.get().outputs.files.files.first().absolutePath

    inputs.property("graalvmHome", graalVmHome)
    inputs.file(dummyJarFile)
    outputs.dir(capCacheDirectory)

    doFirst {
        val nativeImageFile = nativeImage.get()
        require(nativeImageFile.canExecute()) {
            "GraalVM native-image executable was not found: ${nativeImageFile.absolutePath}"
        }

        val outputDirectory = capCacheDirectory.get().asFile
        outputDirectory.mkdirs()
        val arguments = arrayOf(
            nativeImageFile.absolutePath,
            "-cp",
            dummyJarFile,
            "-H:+SharedLibrary",
            "-H:Name=usercode",
            "-H:PageSize=16384",
            "-Dsvm.targetName=iOS",
            "-Dsvm.targetArch=arm64",
            "-H:+NewCAPCache",
            "-H:+ExitAfterCAPCache",
            "-H:CAPCacheDir=${outputDirectory.absolutePath}",
            "-Dsvm.platform=org.graalvm.nativeimage.Platform\$IOS_AARCH64",
        )

        println(arguments.joinToString(" "))
        commandLine(*arguments)
    }
}
