# Jenkins CI/CD Pipeline - OpenShift Deployment Guides

## Overview

Production-grade Jenkins CI/CD pipeline for deploying Spring Petclinic on OpenShift 4.12 using:
- Jenkins Kubernetes Plugin for dynamic agent provisioning
- OpenShift BuildConfig (Buildah) for container image builds
- Nexus registry for image storage
- Automated deployment and verification

---

## Prerequisites

### Cluster Requirements
- OpenShift 4.12+ cluster
- User with project creation privileges
- Storage class `hungpq52-storageclass` with RWX support
- Jenkins Controller with Kubernetes Plugin installed

### Registry Access
- Nexus registry: `nexus.apps.s68`
- Nexus credentials: `admin` / `123456789`
- Red Hat registry credentials from https://access.redhat.com/terms-based-registry/

### Tools
- `oc` CLI 4.12+
- Git

---

## Quick Start

### Step 1: Create Namespaces

```bash
oc new-project jenkins-agents-hungpq52
oc new-project petclinic-hungpq52
```

### Step 2: Create Secrets

**Nexus Push Secret:**
```bash
oc create secret docker-registry nexus-push-secret \
  --docker-server=nexus.apps.s68 \
  --docker-username=admin \
  --docker-password=123456789 \
  -n petclinic-hungpq52
```

**Red Hat Pull Secret:**
```bash
oc create secret docker-registry redhat-pull-secret \
  --docker-server=registry.redhat.io \
  --docker-username=<YOUR_RH_USERNAME> \
  --docker-password=<YOUR_RH_TOKEN> \
  -n jenkins-agents-hungpq52
```

### Step 3: Apply RBAC Configuration

```bash
oc apply -f agent-rbac.yaml
```

Verify:
```bash
oc get sa jenkins-agent -n jenkins-agents-hungpq52
oc auth can-i create builds --as=system:serviceaccount:jenkins-agents-hungpq52:jenkins-agent -n petclinic-hungpq52
# Expected: yes
```

### Step 4: Create Storage

```bash
oc apply -f openshift/pvc-jenkins-workspace.yaml
```

Verify:
```bash
oc get pvc jenkins-agent-workspace -n jenkins-agents-hungpq52
# Wait for STATUS: Bound
```

### Step 5: Create BuildConfig

```bash
oc apply -f openshift/buildconfig-petclinic.yaml
```

Verify:
```bash
oc get bc petclinic -n petclinic-hungpq52
```

### Step 6: Configure Jenkins Job

1. Open Jenkins UI
2. Create new **Pipeline** job
3. Configure:
   - **Pipeline Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: Your repository containing this Jenkinsfile
   - **Script Path**: `Jenkinsfile`
4. Save

### Step 7: Run Pipeline

1. Click **Build Now**
2. Monitor console output
3. Verify all stages complete successfully

### Step 8: Access Application

```bash
ROUTE=$(oc get route petclinic -n petclinic-hungpq52 -o jsonpath='{.spec.host}')
echo "Application URL: http://${ROUTE}"
```

Open the URL in your browser to access Spring Petclinic.

---

## Architecture

### Namespaces
- `jenkins-agents-hungpq52`: Jenkins agent pods
- `petclinic-hungpq52`: Application deployment

### Pipeline Flow
```
Checkout → Maven Build → Build Image → Push to Nexus → Deploy → Verify
```

### Components

**RBAC:**
- ServiceAccount: `jenkins-agent`
- Roles: `jenkins-agent`, `jenkins-deployer`
- Cross-namespace permissions for build and deploy

**Storage:**
- PVC: `jenkins-agent-workspace` (20Gi, RWX)
- Shared workspace for Maven cache and build artifacts

**Build:**
- BuildConfig: `petclinic` (Docker strategy)
- Output: `nexus.apps.s68/petclinic:latest`

**Agent Pod:**
- Container 1: `jnlp` (jenkins-agent-base-rhel8 + oc CLI)
- Container 2: `maven` (Maven 3.9 + Java 17)

---

## Validation

### Check Infrastructure
```bash
# Namespaces
oc get projects | grep hungpq52

# Secrets
oc get secret -n jenkins-agents-hungpq52 | grep redhat-pull-secret
oc get secret -n petclinic-hungpq52 | grep nexus-push-secret

# RBAC
oc get sa,role,rolebinding -n jenkins-agents-hungpq52
oc get role,rolebinding -n petclinic-hungpq52

# Storage
oc get pvc -n jenkins-agents-hungpq52

# BuildConfig
oc get bc -n petclinic-hungpq52
```

### Monitor Build
```bash
# Watch agent pods
oc get pods -n jenkins-agents-hungpq52 -w

# Check build logs
oc logs -f bc/petclinic -n petclinic-hungpq52

# Check deployment
oc get pods,svc,route -n petclinic-hungpq52
```

---

## Troubleshooting

### ImagePullBackOff on jenkins-agent-base-rhel8
```bash
# Check secret exists
oc get secret redhat-pull-secret -n jenkins-agents-hungpq52

# Verify credentials
oc get secret redhat-pull-secret -n jenkins-agents-hungpq52 -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d

# Recreate if needed
oc delete secret redhat-pull-secret -n jenkins-agents-hungpq52
oc create secret docker-registry redhat-pull-secret \
  --docker-server=registry.redhat.io \
  --docker-username=<YOUR_RH_USERNAME> \
  --docker-password=<YOUR_RH_TOKEN> \
  -n jenkins-agents-hungpq52
```

### RBAC Permission Denied
```bash
# Test permissions
oc auth can-i create builds --as=system:serviceaccount:jenkins-agents-hungpq52:jenkins-agent -n petclinic-hungpq52

# Reapply RBAC
oc apply -f agent-rbac.yaml
```

### PVC Not Binding
```bash
# Check storage class
oc get sc hungpq52-storageclass

# Describe PVC
oc describe pvc jenkins-agent-workspace -n jenkins-agents-hungpq52
```

### Build Push Failure
```bash
# Check Nexus connectivity
curl -I http://nexus.apps.s68

# Verify secret
oc get secret nexus-push-secret -n petclinic-hungpq52

# Check build logs
oc logs -f bc/petclinic -n petclinic-hungpq52
```

---

## File Structure

```
jenkins-openshift/
├── Jenkinsfile                           # Pipeline definition
├── pod-template-agent.yaml               # Pod template reference
├── agent-rbac.yaml                       # RBAC configuration
├── task.plan                             # Execution checklist
├── README.md                             # This file
└── openshift/
    ├── pvc-jenkins-workspace.yaml        # Shared storage
    └── buildconfig-petclinic.yaml        # Build configuration
```

---

## Configuration Reference

| Parameter | Value |
|-----------|-------|
| Agent Namespace | `jenkins-agents-hungpq52` |
| App Namespace | `petclinic-hungpq52` |
| Storage Class | `hungpq52-storageclass` |
| Nexus Registry | `nexus.apps.s68` |
| Agent Image | `registry.redhat.io/ocp-tools-4/jenkins-agent-base-rhel8:latest` |
| Maven Image | `maven:3.9-eclipse-temurin-17` |
| Java Version | 17 |

---

## References

- [OpenShift 4.12 Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.12/)
- [Jenkins Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [Spring Petclinic](https://github.com/spring-projects/spring-petclinic)
- [OpenShift BuildConfig](https://docs.redhat.com/en/documentation/openshift_container_platform/4.12/html/builds_using_buildconfig/)

---

**Status:** Ready for deployment

**Last Updated:** 2026-01-18
