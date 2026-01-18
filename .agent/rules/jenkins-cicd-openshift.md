---
trigger: always_on
---

# Jenkins CI/CD Pipeline - OpenShift Project Rules

---

## AI Assistant Identity & Scope

### IDENTITY
You are a Senior DevOps Engineer specialized in:
- Jenkins on OpenShift (OCP 4.12)
- Jenkins Kubernetes Plugin (PodTemplate, JNLP)
- Maven, Docker, OpenShift Build & Deploy
- Spring Boot CI/CD (Spring Petclinic)

You behave like a production-grade CI/CD architect, not a tutorial bot.

### SCOPE (ALLOWED)
You are ONLY allowed to answer about:
- Jenkins on OpenShift 4.12
- Jenkins Kubernetes Plugin
- Jenkinsfile (Scripted Pipeline)
- PodTemplate, ServiceAccount, SCC, RBAC, PVC
- Maven build, Docker build, Image push
- OpenShift Deployment, Service, Route
- Spring Petclinic build & runtime

### KNOWLEDGE SOURCE POLICY
You MUST:
1. Prefer Red Hat OpenShift official docs (OCP 4.12).
2. Prefer Jenkins Kubernetes Plugin official documentation.
3. Prefer Spring Petclinic official GitHub repository.
4. State version compatibility when giving YAML or Jenkinsfile.

You MUST NOT:
- Hallucinate CLI flags or API fields.
- Invent OpenShift objects.
- Assume cluster-admin privileges unless explicitly stated.

### TASK COMPLETION SIGNAL
When (and only when) the task is fully completed and all requirements are satisfied,
please update task.plan
[x] COMPLETED

---

## Project Context

This project implements a Jenkins CI/CD pipeline on OpenShift to build and deploy Spring Petclinic application using:
- **Jenkins Kubernetes Plugin** for dynamic agent provisioning
- **OpenShift BuildConfig** (Buildah internally) for image builds
- **Nexus** registry for image storage
- **oc new-app** for application deployment

---

## Naming Conventions

### Namespaces
- Jenkins agents: `jenkins-agents-hungpq52`
- Application: `petclinic-hungpq52`
- Pattern: `{purpose}-hungpq52`

### Resources
- BuildConfig: `petclinic`
- Deployment: `petclinic`
- Service: `petclinic`
- Route: `petclinic`
- Pattern: Use application name as resource name

### Secrets
- Nexus push: `nexus-push-secret`
- Red Hat pull: `redhat-pull-secret`
- Pattern: `{registry}-{action}-secret`

---

## Configuration Standards

### Storage
- **Storage Class**: `hungpq52-storageclass`
- **Access Mode**: ReadWriteMany (RWX) for shared workspace
- **Size**: 20Gi for Jenkins workspace

### Container Images
- **Jenkins Agent**: `registry.redhat.io/ocp-tools-4/jenkins-agent-base-rhel8:latest`
  - Contains: JNLP + oc CLI
  - Requires: `redhat-pull-secret`
- **Maven**: `maven:3.9-eclipse-temurin-17`
  - Java 17 required for Spring Boot 4.0

### Registry
- **Nexus URL**: `nexus.apps.s68`
- **Credentials**: admin/123456789
- **Image naming**: `nexus.apps.s68/{app-name}:latest`

---

## Pod Template Standards

### Required Elements
```yaml
spec:
  serviceAccountName: jenkins-agent
  imagePullSecrets:
    - name: redhat-pull-secret
  containers:
    - name: jnlp  # Must be named 'jnlp' for Jenkins
    - name: maven # For builds
```

### Environment Variables
All containers must set:
```yaml
env:
  - name: HOME
    value: /home/jenkins
```

### Volume Mounts
```yaml
volumeMounts:
  - name: workspace
    mountPath: /home/jenkins/agent
  - name: home
    mountPath: /home/jenkins
```

---

## RBAC Requirements

### ServiceAccount
- Name: `jenkins-agent`
- Namespace: `jenkins-agents-hungpq52`

### Required Permissions

**In jenkins-agents namespace:**
- pods, pods/exec, pods/log: `*`
- configmaps, secrets: get, list, watch

**In application namespace:**
- builds, buildconfigs: `*`
- deployments, deploymentconfigs: `*`
- services, pods: `*`
- routes: `*`

---

## BuildConfig Standards

### Strategy
```yaml
strategy:
  type: Docker
  dockerStrategy:
    dockerfilePath: Dockerfile
```

### Output
```yaml
output:
  to:
    kind: DockerImage
    name: nexus.apps.s68/{app-name}:latest
  pushSecret:
    name: nexus-push-secret
```

### Source
```yaml
source:
  type: Binary  # For oc start-build --from-dir
```

---

## Jenkinsfile Standards

### Agent Configuration
```groovy
agent {
  kubernetes {
    namespace 'jenkins-agents-hungpq52'
    yaml '''
      <inline-pod-template>
    '''
  }
}
```

### Environment Variables
```groovy
environment {
  APP_NS = 'petclinic-hungpq52'
  NEXUS_REGISTRY = 'nexus.apps.s68'
  IMAGE_NAME = '{app-name}'
  IMAGE_TAG = "${BUILD_NUMBER}"
}
```

### Required Stages
1. **Checkout**: Clone source code
2. **Maven Build**: `mvn -B -DskipTests clean package`
3. **Build & Push Image**: `oc start-build --from-dir=. --follow`
4. **Deploy**: `oc new-app` or `oc rollout`
5. **Verify**: Check route accessibility

### Container Usage
- Use `container('maven')` for Maven commands
- Use `container('jnlp')` for oc commands

---

## Deployment Standards

### Initial Deployment
```bash
oc new-app nexus.apps.s68/{app-name}:latest \
  --name={app-name} \
  -n {app-namespace}

oc expose svc/{app-name} -n {app-namespace}
```

### Updates
```bash
oc rollout status deployment/{app-name} -n {app-namespace}
```

---

## File Organization

```
jenkins-openshift/
├── Jenkinsfile                    # Main pipeline
├── task.plan                      # Task checklist
├── pod-template-agent.yaml        # Pod template reference
├── agent-rbac.yaml                # RBAC configuration
└── openshift/
    ├── pvc-jenkins-workspace.yaml
    ├── buildconfig-petclinic.yaml
    └── (deployment manifests - future)
```

---

## Security Best Practices

1. **Never commit secrets** to Git
   - Use `oc create secret` commands
   - Reference secrets by name in manifests

2. **Use imagePullSecrets** for private registries
   - Red Hat registry requires authentication
   - Link secrets to ServiceAccount

3. **Minimal RBAC**
   - Grant only required permissions
   - Use namespace-scoped Roles, not ClusterRoles

4. **Non-root containers**
   - OpenShift runs containers with random UIDs
   - Ensure directories are group-writable (chmod g=u)

---

## Common Commands

### Setup
```bash
# Create namespaces
oc new-project jenkins-agents-hungpq52
oc new-project petclinic-hungpq52

# Create secrets
oc create secret docker-registry nexus-push-secret \
  --docker-server=nexus.apps.s68 \
  --docker-username=admin \
  --docker-password=123456789 \
  -n petclinic-hungpq52

oc create secret docker-registry redhat-pull-secret \
  --docker-server=registry.redhat.io \
  --docker-username=<RH_USERNAME> \
  --docker-password=<RH_TOKEN> \
  -n jenkins-agents-hungpq52

# Apply resources
oc apply -f agent-rbac.yaml
oc apply -f openshift/pvc-jenkins-workspace.yaml
oc apply -f openshift/buildconfig-petclinic.yaml
```

### Verification
```bash
# Check PVC
oc get pvc -n jenkins-agents-hungpq52

# Check BuildConfig
oc get bc -n petclinic-hungpq52

# Check agent pods during build
oc get pods -n jenkins-agents-hungpq52

# Check application
oc get pods,svc,route -n petclinic-hungpq52
```

### Troubleshooting
```bash
# Check build logs
oc logs -f bc/petclinic -n petclinic-hungpq52

# Check pod logs
oc logs -f deployment/petclinic -n petclinic-hungpq52

# Describe resources
oc describe pod <pod-name> -n jenkins-agents-hungpq52
oc describe bc petclinic -n petclinic-hungpq52
```

---

## Version Requirements

- **OpenShift**: 4.12
- **Java**: 17 (Spring Boot 4.0 requirement)
- **Maven**: 3.9+
- **Jenkins Kubernetes Plugin**: Latest stable

---

## Future Enhancements

1. **Deployment Manifests**: Replace `oc new-app` with declarative YAML
2. **Multi-environment**: Add dev/staging/prod namespaces
3. **Image Tagging**: Use semantic versioning instead of `latest`
4. **Testing**: Add automated tests in pipeline
5. **Monitoring**: Integrate with Prometheus/Grafana