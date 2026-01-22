// Jenkins Pipeline for Spring Petclinic on OpenShift
// Uses Jenkins Kubernetes Plugin with inline pod template
pipeline {
  agent {
    kubernetes {
      namespace 'jenkins-agents-hungpq52'
      yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-agent
  imagePullSecrets:
    - name: redhat-pull-secret
  containers:
  - name: jnlp
    image: registry.redhat.io/ocp-tools-4/jenkins-agent-base-rhel8@sha256:d9ba10b836a4d2cebb9e8537b7a46202301432273b6d75cafb3f7d0815fc4558
    env:
    - name: HOME
      value: /home/jenkins
    volumeMounts:
    - name: workspace
      mountPath: /home/jenkins/agent
    - name: home
      mountPath: /home/jenkins
  - name: maven
    image: maven:3.9-eclipse-temurin-25
    command: ["cat"]
    tty: true
    env:
    - name: HOME
      value: /home/jenkins
    - name: MAVEN_OPTS
      value: "-Dmaven.repo.local=/home/jenkins/.m2/repository"
    volumeMounts:
    - name: workspace
      mountPath: /home/jenkins/agent
    - name: home
      mountPath: /home/jenkins
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["/busybox/sleep"]
    args: ["99d"]
    tty: true
    workingDir: /home/jenkins/agent
    env:
    - name: HOME
      value: /home/jenkins
    volumeMounts:
    - name: workspace
      mountPath: /home/jenkins/agent
    - name: kaniko-secret
      mountPath: /kaniko/.docker
  volumes:
  - name: workspace
    emptyDir: {}
  - name: home
    emptyDir: {}
  - name: kaniko-secret
    secret:
      secretName: nexus-push-secret
      items:
      - key: .dockerconfigjson
        path: config.json
      '''
    }
  }
  
  environment {
    APP_NS = 'hungpq52-app'
    NEXUS_REGISTRY = 'registry.apps.ocp.bankhub.s68'
    IMAGE_NAME = 'petclinic-hungpq52'
    IMAGE_TAG = "${BUILD_NUMBER}"
    FULL_IMAGE = "${NEXUS_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
  }
  
  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Test') {
      steps {
        container('jnlp') {
          sh 'oc get pods -n jenkins-agents-hungpq52'
        }
      }
    }
    
    stage('Compile') {
      steps {
        container('maven') {
          sh 'mvn clean package -DskipTests -Dcheckstyle.skip=true'
        }
      }
    }
    
    stage('Build & Push Image') {
      steps {
        container('kaniko') {
          sh """
            echo "Current directory: \$(pwd)"
            echo "Files in workspace:"
            ls -la
            
            # Verify /kaniko/executor exists
            if [ ! -f /kaniko/executor ]; then
              echo "ERROR: /kaniko/executor not found!"
              exit 1
            fi
            
            # Run Kaniko executor
            /kaniko/executor \\
              --context=\$(pwd) \\
              --dockerfile=\$(pwd)/Dockerfile \\
              --destination=${FULL_IMAGE} \\
              --skip-tls-verify \\
              --insecure \\
              --insecure-registry=${NEXUS_REGISTRY}
            
            echo "✅ Image pushed to ${FULL_IMAGE}"
          """
        }
      }
    }
  }
}
