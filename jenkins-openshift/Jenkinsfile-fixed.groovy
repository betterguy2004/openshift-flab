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
    image: registry.redhat.io/ocp-tools-4/jenkins-agent-base-rhel8:latest
    env:
    - name: HOME
      value: /home/jenkins
    volumeMounts:
    - name: workspace
      mountPath: /home/jenkins/agent
    - name: home
      mountPath: /home/jenkins
  - name: maven
    image: maven:3.9-eclipse-temurin-17
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
    workingDir: /workspace
    env:
    - name: HOME
      value: /workspace
    volumeMounts:
    - name: workspace
      mountPath: /workspace
    - name: kaniko-secret
      mountPath: /kaniko/.docker
  volumes:
  - name: workspace
    persistentVolumeClaim:
      claimName: jenkins-agent-workspace
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
    IMAGE_TAG = "1"
    FULL_IMAGE = "${NEXUS_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
  }
  
  stages {
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
            # Verify /kaniko/executor exists
            if [ ! -f /kaniko/executor ]; then
              echo "ERROR: /kaniko/executor not found!"
              exit 1
            fi
            
            # Copy build artifacts to writable workspace
            echo "Copying artifacts to /workspace..."
            cp -r /home/jenkins/agent/* /workspace/ 2>/dev/null || true
            cd /workspace
            
            # List files to verify
            echo "Files in /workspace:"
            ls -la
            
            # Run Kaniko executor
            /kaniko/executor \\
              --context=/workspace \\
              --dockerfile=/workspace/Dockerfile \\
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
