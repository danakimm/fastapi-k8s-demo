import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildFeatures.commitStatusPublisher
import jetbrains.buildServer.configs.kotlin.buildSteps.script
import jetbrains.buildServer.configs.kotlin.triggers.finishBuildTrigger
import jetbrains.buildServer.configs.kotlin.triggers.vcs

version = "2026.2"

project {
    description = "FastAPI CI/CD pipeline with TeamCity, Nexus and Kubernetes"

    buildType(Build)
    buildType(Deploy)
}

object Build : BuildType({
    name = "Build"

    params {
        param("env.BUILD_NUMBER", "%build.number%")
        param("env.BUILD_VCS_NUMBER", "%build.vcs.number%")
        param("env.DOCKER_IMAGE", "fastapi-k8s-demo")
    }

    outputParams {
        param("imageTag", "%system.build.number%")
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

    features {
        commitStatusPublisher {
            publisher = github {
                statusCheckName = "Build (fastapi-k8s-demo)"
                githubUrl = "https://api.github.com"
                authType = personalToken {
                    token = "credentialsJSON:3db77f0a-b1dc-41b9-884a-39fcc45211a1"
                }
            }
        }
    }
})

object Deploy : BuildType({
    name = "Deploy"
    type = BuildTypeSettings.Type.DEPLOYMENT
    buildNumberPattern = "%dep.Build.system.build.number%"

    params {
        param("env.DOCKER_IMAGE", "fastapi-k8s-demo")
        param("env.IMAGE_TAG", "%dep.Build.imageTag%")
        param("env.KUBE_API_URL", "https://100.70.246.32:6443")
        param("env.KUBE_NAMESPACE", "fastapi-demo")
        password("env.KUBE_TOKEN", "credentialsJSON:07336fcd-c617-4d90-908b-f579a7312ece")
        password("env.KUBE_CA_B64", "credentialsJSON:0d0b7d3a-bb55-46cc-b679-55af3e6c6a65")
    }

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        script {
            name = "Helm Deploy"
            id = "Helm_Deploy"
            scriptContent = """
                set -eu
                bash .teamcity/scripts/helm-deploy.sh
            """.trimIndent()
        }
    }

    triggers {
        finishBuildTrigger {
            buildType = "${Build.id}"
            successfulOnly = true
            branchFilter = "+:main"
        }
    }

    dependencies {
        snapshot(Build) {
            reuseBuilds = ReuseBuilds.SUCCESSFUL
            onDependencyFailure = FailureAction.CANCEL
        }
    }
})
