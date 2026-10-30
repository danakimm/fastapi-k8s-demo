import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildSteps.script
import jetbrains.buildServer.configs.kotlin.triggers.vcs

version = "2026.2"

project {
    description = "FastAPI CI/CD pipeline with TeamCity, Nexus and Kubernetes"

    buildType(Build)
}

object Build : BuildType({
    name = "Build"

    params {
        param("env.BUILD_NUMBER", "%build.number%")
        param("env.BUILD_VCS_NUMBER", "%build.vcs.number%")
    }

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        script {
            name = "Lint & Test"
            id = "Lint_Test"
            scriptContent = """
                set -eu
                bash .teamcity/scripts/lint-test.sh
            """.trimIndent()
        }

        script {
            name = "Docker Build"
            id = "Docker_Build"
            scriptContent = """
                set -eu
                bash .teamcity/scripts/docker-build.sh
            """.trimIndent()
        }

        script {
            name = "Nexus Push"
            id = "Nexus_Push"
            scriptContent = """
                set -eu
                bash .teamcity/scripts/nexus-push.sh
            """.trimIndent()
        }
    }

    triggers {
        vcs {
        }
    }
})
