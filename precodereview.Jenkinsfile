#!/usr/bin/env groovy

def bob = "./bob/bob -r ci/common_ruleset2.0.yaml"
def LOCKABLE_RESOURCE_LABEL = "kaas"
def Boolean FOSS_CHANGED = true
@Library('oss-common-pipeline-lib@dVersion-2.0.0-hybrid') _ // Shared library from the OSS/com.ericsson.oss.ci/oss-common-ci-utils

pipeline {
    agent {
        label env.NODE_LABEL
    }

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        KUBECONFIG = "${WORKSPACE}/.kube/config"
        MAVEN_CLI_OPTS = "-Duser.home=${env.HOME} -B -s ${env.WORKSPACE}/settings.xml"
        CREDENTIALS_SELI_ARTIFACTORY = credentials('SELI_ARTIFACTORY')
    }

    stages {
        stage('Prepare') {
            steps {
                deleteDir()
                script {
                    ci_pipeline_init.clone_project()
                    ci_pipeline_init.clone_ci_repo("common")
                    ci_pipeline_init.setEnvironmentVariables()
                    ci_pipeline_init.setBuildName()
                    ci_pipeline_init.updateJava17Builder("common")
                }
                sh "${bob} --help"
                sh "${bob} -lq"
                echo 'Inject settings.xml into workspace:'
                configFileProvider([configFile(fileId: "${env.SETTINGS_CONFIG_FILE_NAME}", targetLocation: "${env.WORKSPACE}")]) {}

                sh "${bob} clean"
                ci_load_custom_stages("stage-marker-prepare")
            }
        }

        stage('Init') {
            steps {
                sh "${bob} init-precodereview"
                ci_load_custom_stages("stage-marker-init")
            }
        }

        stage('Lint') {
            when {
                expression {
                    env.LINT_ENABLED == "true"
                }
            }
            steps {
                parallel(
                    "lint markdown": {
                        sh "${bob} lint:markdownlint lint:vale"
                    },
                    "lint helm": {
                        sh "${bob} lint:helm"
                    },
                    "lint helm design rule checker": {
                        sh "${bob} lint:helm-chart-check"
                    },
                    "lint code": {
                        sh "${bob} lint:license-check"
                    },
                    "lint OpenAPI spec": {
                        sh "${bob} lint:oas-bth-linter"
                    },
                    "lint metrics": {
                        sh "${bob} lint:metrics-check"
                    },
                    "SDK Validation": {
                        script {
                            if (env.validateSdk == "true") {
                                sh "${bob} validate-sdk"
                            }
                        }
                    }
                )
            }
            post {
                always {
                    archiveArtifacts allowEmptyArchive: true, artifacts: '**/*bth-linter-output.html, **/design-rule-check-report.*'
                }
            }
        }

        stage('Vulnerability Analysis') {
            when {
                expression {
                    env.VA_ENABLED == "true"
                }
            }
            steps {
                parallel(
                    "Hadolint": {
                        script {
                            if (env.HADOLINT_ENABLED == "true") {
                                sh "${bob} hadolint-scan"
                                echo "Evaluating Hadolint Scan Resultcodes..."
                                sh "${bob} evaluate-design-rule-check-resultcodes"
                                archiveArtifacts "build/va-reports/hadolint-scan/**.*"
                            } else {
                                echo "stage Hadolint skipped"
                            }
                        }
                    },
                    "Kubeaudit": {
                        script {
                            if (env.KUBEAUDIT_ENABLED == "true") {
                                sh "${bob} kube-audit"
                                archiveArtifacts "build/va-reports/kube-audit-report/**/*"
                            } else {
                                echo "stage Kubeaudit skipped"
                            }
                        }
                    },
                    "Kubesec": {
                        script {
                            if (env.KUBESEC_ENABLED == "true") {
                                sleep(10)
                                sh "${bob} kubesec-scan"
                                archiveArtifacts "build/va-reports/kubesec-reports/*"
                            } else {
                                echo "stage Kubsec skipped"
                            }
                        }
                    }
                )
            }
        }

        stage('Generate Vulnerability report V2.0') {
            when {
                expression {
                    env.VA_REPORT_GENERATE_ENABLED == "true"
                }
            }
            steps {
                script {
                        sh "${bob} generate-VA-report-V2:create-va-folders"
                        sh "${bob} generate-VA-report-V2:no-upload"
                        sh "${bob} generate-VA-report-V2:va-report-to-html"
                }
                archiveArtifacts allowEmptyArchive: true, artifacts: 'build/va-reports/Vulnerability_Report_2.0.md'
                archiveArtifacts allowEmptyArchive: true, artifacts: 'build/html/html-va-report/Vulnerability_Report_2.0.html'
                ci_load_custom_stages("stage-marker-va-report")
            }
        }

        stage('Build') {
            when {
                expression {
                    env.BUILD_ENABLED == "true"
                }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'SELI_ARTIFACTORY', usernameVariable: 'SELI_ARTIFACTORY_REPO_USER', passwordVariable: 'SELI_ARTIFACTORY_REPO_PASS')]) {
                    sh "${bob} build"
                    ci_load_custom_stages("stage-marker-build")
                }
            }
        }

        stage('Parallel Streams') {
            parallel {
                stage('Docs Stream') {
                    stages {
                        stage('Generate Docs') {
                            when {
                                expression {
                                    env.GENERATE_ENABLED == "true"
                                }
                            }
                            steps {
                                sh "${bob} generate-docs"
                                archiveArtifacts "build/doc/**/*.*"
                                publishHTML(target: [
                                    allowMissing: false,
                                    alwaysLinkToLastBuild: false,
                                    keepAll: true,
                                    reportDir: 'build/doc',
                                    reportFiles: 'CTA_api.html',
                                    reportName: 'REST API Documentation'
                                ])

                            }
                        }

                        stage('API NBC Check') {
                            when {
                                expression {
                                    env.GENERATE_ENABLED == "true"
                                }
                            }
                            steps {
                                sh "${bob} rest-2-html:check-has-open-api-been-modified"
                                script {
                                    def val = readFile '.bob/var.has-openapi-spec-been-modified'
                                    if (val.trim().equals("true")) {
                                        sh "${bob} rest-2-html:detect-breaking-changes-openapispec"
                                        sh "${bob} rest-2-html:zip-open-api-doc"
                                        sh "${bob} rest-2-html:generate-html-output-files"

                                        manager.addInfoBadge("OpenAPI spec has changed. Review the Archived HTML Output files: rest2html*.zip")
                                        archiveArtifacts allowEmptyArchive: true, artifacts: "rest_conversion_log.txt, rest2html*.zip"
                                        echo "Sending email to CPI document reviewers distribution list: ${env.EMAIL}"
                                        try {
                                            mail to: "${env.EMAIL}",
                                                from: "${env.GERRIT_PATCHSET_UPLOADER_EMAIL}",
                                                cc: "${env.GERRIT_PATCHSET_UPLOADER_EMAIL}",
                                                subject: "[${env.JOB_NAME}] OpenAPI specification has been updated and is up for review",
                                                body: "The OpenAPI spec documentation has been updated.<br><br>" +
                                                "Please review the patchset and archived HTML output files (rest2html*.zip) linked here below:<br><br>" +
                                                "&nbsp;&nbsp;Gerrit Patchset: ${env.GERRIT_CHANGE_URL}<br>" +
                                                "&nbsp;&nbsp;HTML output files: ${env.BUILD_URL}artifact <br><br><br><br>" +
                                                "<b>Note:</b> This mail was automatically sent as part of the following Jenkins job: ${env.BUILD_URL}",
                                                mimeType: 'text/html'
                                        } catch (Exception e) {
                                            echo "Email notification was not sent."
                                            print e
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                stage('Sonar Stream') {
                    stages {
                        stage('Test') {
                            when {
                                expression {
                                    env.TEST_ENABLED == "true"
                                }
                            }
                            steps {
                                withCredentials([usernamePassword(credentialsId: 'SELI_ARTIFACTORY', usernameVariable: 'SELI_ARTIFACTORY_REPO_USER', passwordVariable: 'SELI_ARTIFACTORY_REPO_PASS')]) {
                                    sh "${bob} test"
                                    ci_load_custom_stages("stage-marker-test")
                                }
                            }
                        }

                        stage('Generate Contract Test Coverage Report') {
                            when {
                                expression {
                                    env.CONTRACT_TEST_COVERAGE == "true"
                                }
                            }
                            steps {
                                withCredentials([usernamePassword(credentialsId: 'SELI_ARTIFACTORY', usernameVariable: 'SELI_ARTIFACTORY_REPO_USER', passwordVariable: 'SELI_ARTIFACTORY_REPO_PASS')]) {
                                    sh "${bob} contract-test-coverage:generate-report"
                                }
                            }
                            post {
                                success {
                                    publishHTML (target: [
                                        allowMissing: false,
                                        alwaysLinkToLastBuild: false,
                                        keepAll: true,
                                        reportDir: 'target/swagger-coverage-results',
                                        reportFiles: 'swagger-coverage-report.html',
                                        reportName: 'Contract Test Coverage Report'
                                    ])
                                    sh "${bob} contract-test-coverage:verify-coverage"
                                }
                            }
                        }

                        stage('SonarQube') {
                            when {
                                expression {
                                    env.SQ_ENABLED == "true" && env.SQ_LOCAL_ENABLED == "true"
                                }
                            }
                            steps {
                                withCredentials([usernamePassword(credentialsId: 'SELI_ARTIFACTORY', usernameVariable: 'SELI_ARTIFACTORY_REPO_USER', passwordVariable: 'SELI_ARTIFACTORY_REPO_PASS')]) {
                                    withSonarQubeEnv("${env.SQ_SERVER}") {
                                        sh "${bob} sonar-enterprise-pcr"
                                    }
                                }
                                timeout(time: 5, unit: 'MINUTES') {
                                    waitUntil {
                                        withSonarQubeEnv("${env.SQ_SERVER}") {
                                            script {
                                                return ci_pipeline_scripts.getQualityGate()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                stage('Image Stream') {
                    stages {
                        stage('Image') {
                            when {
                                expression {
                                    env.IMAGE_ENABLED == "true"
                                }
                            }
                            steps {
                                script {
                                    ci_pipeline_scripts.retryMechanism("${bob} image", 3)
                                    ci_pipeline_scripts.retryMechanism("${bob} image-dr-check", 3)
                                    ci_load_custom_stages("stage-marker-image")
                                }
                            }
                            post {
                                always {
                                    archiveArtifacts allowEmptyArchive: true, artifacts: '**/image-design-rule-check-report*'
                                }
                            }
                        }

                        stage('Package') {
                            when {
                                expression {
                                    env.PACKAGE_ENABLED == "true"
                                }
                            }
                            steps {
                                script {
                                    withCredentials([usernamePassword(credentialsId: 'SELI_ARTIFACTORY', usernameVariable: 'SELI_ARTIFACTORY_REPO_USER', passwordVariable: 'SELI_ARTIFACTORY_REPO_PASS'),
                                        file(credentialsId: 'docker-config-json', variable: 'DOCKER_CONFIG_JSON')
                                    ]) {
                                        ci_pipeline_scripts.checkDockerConfig()
                                        ci_pipeline_scripts.retryMechanism("${bob} package", 3)
                                        sh "${bob} delete-images-from-agent:delete-internal-image"
                                        ci_load_custom_stages("stage-marker-package")
                                    }
                                }
                            }
                        }
                    }
                }

                stage('FOSSA Stream') {
                    stages {
                        stage('Maven Dependency Tree Check') {
                            when {
                                expression {
                                    env.FOSSA_ENABLED == "true"
                                }
                            }
                            steps {
                                script {
                                    withCredentials([usernamePassword(credentialsId: 'SELI_ARTIFACTORY', usernameVariable: 'SELI_ARTIFACTORY_REPO_USER', passwordVariable: 'SELI_ARTIFACTORY_REPO_PASS')]) {
                                        sh "${bob} generate-mvn-dep-tree"
                                    }
                                    if (ci_pipeline_scripts.compareDepTreeFiles("${WORKSPACE}/fossa/local_dep_tree.txt", "${WORKSPACE}/build/dep_tree.txt")) {
                                        FOSS_CHANGED = false
                                    }
                                    echo "FOSS Changed: $FOSS_CHANGED"
                                }
                                archiveArtifacts allowEmptyArchive: true, artifacts: 'build/dep_tree.txt'
                            }
                        }

                        stage('3PP Analysis') {
                            when {
                                expression { env.FOSSA_ENABLED == "true" && FOSS_CHANGED }
                            }
                            steps {
                                withCredentials([string(credentialsId: 'FOSSA_API_token', variable: 'FOSSA_API_KEY'), string(credentialsId: 'SCAS_token', variable: 'SCAS_TOKEN'), string(credentialsId: 'BAZAAR_token', variable: 'BAZAAR_TOKEN'), string(credentialsId: 'munin_token', variable: 'MUNIN_TOKEN')]) {
                                    sh "${bob} 3pp-analysis"
                                }
                            }
                        }

                        stage('Dependencies Validate') {
                            when {
                                expression { env.FOSSA_ENABLED == "true" && FOSS_CHANGED }
                            }
                            steps {
                                withCredentials([string(credentialsId: 'FOSSA_API_token', variable: 'FOSSA_API_KEY'), string(credentialsId: 'SCAS_token', variable: 'SCAS_TOKEN'), string(credentialsId: 'BAZAAR_token', variable: 'BAZAAR_TOKEN'), string(credentialsId: 'munin_token', variable: 'MUNIN_TOKEN')]) {
                                    sh "${bob} dependencies-validate || true"
                                }
                                ci_load_custom_stages("stage-marker-fossa")
                            }
                        }
                    }
                }
            }
        }

        stage('Post-Parallel Action') {
            steps {
                ci_load_custom_stages("stage-marker-post-parallel")
            }
        }

        stage('K8S Resource Lock') {
            options {
                lock(label: LOCKABLE_RESOURCE_LABEL, variable: 'RESOURCE_NAME', quantity: 1)
            }
            environment {
                K8S_CLUSTER_ID = sh(script: "echo \${RESOURCE_NAME} | cut -d'_' -f1", returnStdout: true).trim()
                K8S_NAMESPACE = sh(script: "echo \${RESOURCE_NAME} | cut -d',' -f1 | cut -d'_' -f2", returnStdout: true).trim()
            }
            stages {
                stage('Create Namespace') {
                    steps {
                        echo "Inject kubernetes config file (${env.K8S_CLUSTER_ID}) based on the Lockable Resource name: ${env.RESOURCE_NAME}"
                        configFileProvider([configFile(fileId: "${env.K8S_CLUSTER_ID}", targetLocation: "${env.KUBECONFIG}")]) {}
                        echo "The namespace (${env.K8S_NAMESPACE}) is reserved and locked based on the Lockable Resource name: ${env.RESOURCE_NAME}"
                        sh "${bob} create-namespace"
                        ci_load_custom_stages("stage-marker-helm")
                    }
                }
                stage('Helm Install') {
                    when {
                        expression {
                            env.HELM_INSTALL_ENABLED == "true"
                        }
                    }
                    steps {
                        script {
                            sh "${bob} helm-dry-run"
                            ci_pipeline_scripts.retryMechanism("${bob} helm-install", 2)
                            ci_load_custom_stages("stage-marker-helm-post") //for custom stage if required in default Helm Install
                        }

                    }
                    post {
                        always {
                            sh "${bob} kaas-info || true"
                            archiveArtifacts allowEmptyArchive: true, artifacts: 'build/kaas-info.log'
                        }
                        unsuccessful {
                            withCredentials([usernamePassword(credentialsId: 'SERO_ARTIFACTORY', usernameVariable: 'SERO_ARTIFACTORY_REPO_USER', passwordVariable: 'SERO_ARTIFACTORY_REPO_PASS')]) {
                                sh "${bob} collect-k8s-logs || true"
                            }
                            archiveArtifacts allowEmptyArchive: true, artifacts: "k8s-logs/*"
                            sh "${bob} delete-namespace"
                            sh "rm -f ${env.KUBECONFIG}"
                        }
                    }
                }
            }
            post {
                cleanup {
                    sh "${bob} delete-namespace"
                    sh "rm -f ${env.KUBECONFIG}"
                }
            }
        }

        stage('EriDoc Upload') {
            when {
                expression {
                    env.ERIDOC_ENABLED == "true"
                }
            }
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'eridoc-user', usernameVariable: 'ERIDOC_USERNAME', passwordVariable: 'ERIDOC_PASSWORD')]) {
                        sh "${bob} eridoc-upload:doc-to-pdf"
                        sh "${bob} eridoc-upload:eridoc-upload-dryrun"
                    }
                    archiveArtifacts allowEmptyArchive: true, artifacts: 'build/eridoc/**/**.*'
                    ci_load_custom_stages("stage-marker-eridoc")
                }
            }
        }

    }
    post {
        success {
            script {
                ci_load_custom_stages("stage-marker-post-success")
                sh "${bob} helm-chart-check-report-warnings"
                ci_pipeline_post.addHelmDRWarningIcon("pcr")
                ci_pipeline_post.commonPostSteps("pcr")
                ci_pipeline_post.modifyBuildDescription("pcr")
            }
        }
        failure {
            script {
                ci_load_custom_stages("stage-marker-post-failure")
                ci_pipeline_post.commonPostSteps("pcr")
                ci_pipeline_post.modifyBuildDescription("pcr")
            }
        }
        always {
            withCredentials([usernamePassword(credentialsId: 'SELI_ARTIFACTORY', usernameVariable: 'SELI_ARTIFACTORY_REPO_USER', passwordVariable: 'SELI_ARTIFACTORY_REPO_PASS')]) {
                sh "python ci/scripts/helm-dr-checker.py validate_helm_dr_compliance"
            }
            sh "${bob} delete-images-from-agent"
            sh "${bob} move-reports"
            archiveArtifacts allowEmptyArchive: true, artifacts: "ci/*.Jenkinsfile, ci/common_ruleset2.0.yaml"
            archiveArtifacts allowEmptyArchive: true, artifacts: "ci/local_ruleset.yaml, ci/custom_stages.yaml, ci/local_pipeline_env.txt"
        }
    }
}
