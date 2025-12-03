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

    afterEvaluate {
        // Workaround for AGP 8.0+ requiring namespace in libraries
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android")
            // Use reflection to avoid compilation errors if the Android plugin isn't applied to the root
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(android)
                
                if (currentNamespace == null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    // Construct a valid namespace from group and name
                    var newNamespace = "${project.group}.${project.name}"
                    newNamespace = newNamespace.replace("-", "_").replace(":", ".")
                    // Ensure it's a valid java package name (simplified)
                    if (newNamespace.startsWith(".")) {
                        newNamespace = "com.example$newNamespace"
                    }
                    println("Setting namespace for ${project.name} to $newNamespace")
                    setNamespace.invoke(android, newNamespace)
                }
            } catch (e: Exception) {
                // Ignore if methods don't exist or other errors
            }
        }
        
        // Fix JVM target incompatibility: Force Java 17 to match Kotlin's default
        if (project.hasProperty("android")) {
            try {
                val android = project.extensions.getByName("android")
                val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                
                val setSourceCompatibility = compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java)
                setSourceCompatibility.invoke(compileOptions, JavaVersion.VERSION_17)
                
                val setTargetCompatibility = compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java)
                setTargetCompatibility.invoke(compileOptions, JavaVersion.VERSION_17)
            } catch (e: Exception) {
                // Ignore
            }
        }

        tasks.withType(JavaCompile::class.java).configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
        
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            kotlinOptions {
                jvmTarget = "17"
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
