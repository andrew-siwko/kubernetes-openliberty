pipeline {
    agent { label 'docker-builder' }

    environment {
        // Use the domain name your K8s cluster uses to resolve the registry
        REGISTRY_DOMAIN = 'kregistry.siwko.org:5000'
        IMAGE_NAME      = 'openliberty-test'
        IMAGE_TAG       = "${env.BUILD_NUMBER}"
        DEPLOYMENT_NAME = 'openliberty-test'
    }

    stages {
        stage('Checkout Code') {
            steps {
                // Jenkins automatically pulls the code from Git here
                checkout scm
            }
        }

        stage('Compile & Test (Local)') {
            steps {
                // Ensure Maven is available on your Jenkins agent. 
                // Alternatively, you can rely entirely on the Dockerfile build step.
                sh 'mvn clean test'
            }
        }
        stage('Build Docker Image') {
            steps {
                echo "Building image: ${REGISTRY_DOMAIN}/${IMAGE_NAME}:${IMAGE_TAG}..."
                // Build the image locally on the RHEL 10 agent
                sh "docker build -t ${REGISTRY_DOMAIN}/${IMAGE_NAME}:${IMAGE_TAG} ."
                sh "docker tag ${REGISTRY_DOMAIN}/${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY_DOMAIN}/${IMAGE_NAME}:latest"
            }
        }

        stage('Build & Push Multi-Arch Image') {
            steps {
                echo "Building & pushing multi-arch image: ${REGISTRY_DOMAIN}/${IMAGE_NAME}:${IMAGE_TAG}..."
                // Cluster has both amd64 (RHEL) and arm64 (Orange Pi) nodes, so the image
                // manifest must cover both platforms. Multi-platform images can't be
                // docker-loaded locally, so build and push happen in one buildx step.
                // Reuse the builder across runs (preserves BuildKit's layer cache and avoids
                // tearing down a builder another concurrent job may be using); only create
                // it if missing. The docker-container driver runs BuildKit in its own
                // container, isolated from the host daemon.json insecure-registries setting,
                // so it needs its own config -- baked in once via a fixed host path, not the
                // repo, so any project's Jenkinsfile can reuse the same line.
                sh "docker buildx inspect multiarch-builder >/dev/null 2>&1 || docker buildx create --name multiarch-builder --driver docker-container --config /etc/buildkit/buildkitd.toml --bootstrap"
                sh "docker buildx use multiarch-builder"
                sh """
                    docker buildx build \
                      --platform linux/amd64,linux/arm64 \
                      -t ${REGISTRY_DOMAIN}/${IMAGE_NAME}:${IMAGE_TAG} \
                      -t ${REGISTRY_DOMAIN}/${IMAGE_NAME}:latest \
                      --push .
                """
            }
        }

        stage('Push to Local Registry') {
            steps {
                echo "Pushing images to local registry..."
                // Since this agent runs on the registry host, we push directly to localhost
                // without encountering external TLS or network routing issues
                sh "docker push ${REGISTRY_DOMAIN}/${IMAGE_NAME}:${IMAGE_TAG}"
                sh "docker push ${REGISTRY_DOMAIN}/${IMAGE_NAME}:latest"
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                echo "Applying manifests and updating deployment image..."
                // Always apply the manifests first so Service or ConfigMap changes take effect
                sh "kubectl apply -f deployment.yaml"
                // Then update the image to the exact build tag
                sh "kubectl set image deployment/${DEPLOYMENT_NAME} openliberty-container=${REGISTRY_DOMAIN}/${IMAGE_NAME}:${IMAGE_TAG}"
            }
        }       

        stage('Verify Deployment Status') {
            steps {
                echo "Verifying rollout status..."
                // Actively monitor the rollout to ensure it doesn't get stuck (e.g. on an ImagePullBackOff)
                sh "kubectl rollout status deployment/${DEPLOYMENT_NAME} --timeout=2m"
            }
        }
    }

    post {
        always {
            echo "Cleaning up local build workspace..."
            // Clean up old workspace files to prevent RHEL disk clutter
            cleanWs()
        }
        success {
            echo "Pipeline completed successfully! Build ${IMAGE_TAG} is now live."
        }
        failure {
            echo "Pipeline failed. Check build logs for details."
        }
    }
}
