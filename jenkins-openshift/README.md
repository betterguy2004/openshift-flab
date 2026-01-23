# Jenkins CI/CD Pipeline - OpenShift Deployment Guides

## Overview

Production-grade Jenkins CI/CD pipeline for deploying Spring Petclinic on OpenShift 4.12 using:
- Jenkins Kubernetes Plugin for dynamic agent provisioning
- **Google Jib** for container image builds (no Docker daemon required)
- Nexus registry for image storage
- Automated deployment and verification

> **🚀 New:** Migrated from OpenShift BuildConfig to Jib for faster, more efficient builds. See [JIB-MIGRATION.md](JIB-MIGRATION.md) for details.


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

### Step 5: Configure Jenkins Job

1. Open Jenkins UI
2. Create new **Pipeline** job
3. Configure:
   - **Pipeline Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: Your repository containing this Jenkinsfile
   - **Script Path**: `Jenkinsfile`
4. Save

### Step 6: Run Pipeline


1. Click **Build Now**
2. Monitor console output
3. Verify all stages complete successfully

### Step 7: Access Application

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
Checkout → Maven Build + Jib Push → Deploy to OpenShift → Verify
```

### Components

**RBAC:**
- ServiceAccount: `jenkins-agent`
- Roles: `jenkins-agent`, `jenkins-deployer`
- Cross-namespace permissions for deployment

**Storage:**
- PVC: `jenkins-agent-workspace` (20Gi, RWX)
- Shared workspace for Maven cache and build artifacts

**Image Build:**
- Tool: Google Jib Maven Plugin
- Base Image: `eclipse-temurin:17-jre-jammy`
- Output: `nexus.apps.s68/petclinic:latest`
- No Docker daemon or BuildConfig required

**Agent Pod:**
- Container 1: `jnlp` (jenkins-agent-base-rhel8 + oc CLI)
- Container 2: `maven` (Maven 3.9 + Java 17 + Jib)


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
```

### Monitor Build
```bash
# Watch agent pods
oc get pods -n jenkins-agents-hungpq52 -w

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

# Test Jib build locally
cd spring-petclinic-main/spring-petclinic-main
export NEXUS_USERNAME=admin
export NEXUS_PASSWORD=123456789
mvn clean package jib:build

# Check Jenkins Maven container logs
oc logs -f <jenkins-agent-pod> -c maven -n jenkins-agents-hungpq52
```

---

## Jib Migration

This project has been migrated from **OpenShift BuildConfig** to **Google Jib** for container image building.

### Why Jib?

✅ **No Docker daemon required** - Builds images directly from Maven  
✅ **Faster builds** - Only rebuilds changed layers (30s vs 4min)  
✅ **Optimized layering** - Separates dependencies from application code  
✅ **No Dockerfile needed** - Configuration in `pom.xml`  
✅ **Better security** - No privileged containers or SCC required  

### Key Changes

| Aspect | Before (BuildConfig) | After (Jib) |
|--------|---------------------|-------------|
| Build tool | OpenShift BuildConfig | Maven Jib Plugin |
| Requires | Dockerfile, BuildConfig YAML | Only pom.xml |
| Build time | ~4 minutes | ~30 seconds |
| Permissions | SCC privileges needed | Standard user |
| Configuration | Multiple files | Single pom.xml |

### Migration Guide

See **[JIB-MIGRATION.md](JIB-MIGRATION.md)** for:
- Detailed comparison
- Configuration guide
- Troubleshooting
- Performance metrics

---

## Legacy Build Solutions (Deprecated)

> **Note:** The following sections document previous BuildConfig-based approaches.  
> They are kept for reference but are **no longer recommended**.

### Problem: Three Build Tools, Three Different Errors

During development, three different image build approaches were tested:

| Tool | Error | Root Cause | Status |
|------|-------|------------|--------|
| **Buildah** | `Error during unshare(CLONE_NEWUSER)` | Needs user namespaces (blocked by SCC) | ❌ Won't work |
| **Kaniko** | `permission denied: unlinkat //bin/sh` | Needs elevated SCC (security risk) | ⚠️ Not recommended |
| **BuildConfig** | `x509: certificate signed by unknown authority` | Base image from untrusted registry | ✅ **FIXED** |

### ✅ Recommended Solution: BuildConfig + Red Hat UBI

**Why BuildConfig?**
- ✅ Native OpenShift solution (uses Buildah internally with proper privileges)
- ✅ Integrated with OpenShift RBAC and Security Context Constraints
- ✅ No security risks or elevated privileges needed
- ✅ Aligns with Red Hat best practices

**Certificate Issue Fix:**

The original Dockerfile used `eclipse-temurin:17-jre-jammy` which pulls from CloudFlare R2 CDN with untrusted certificates.

**Solution:** Use Red Hat Universal Base Image (UBI) instead:

```dockerfile
FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:latest

COPY target/*.jar /deployments/app.jar

USER 185

EXPOSE 8080

ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

ENTRYPOINT ["java", "-jar", "/deployments/app.jar"]
```

**Benefits:**
- ✅ Trusted by OpenShift by default (no certificate issues)
- ✅ Optimized for OpenShift (handles random UIDs)
- ✅ Smaller image size (runtime-only, no build tools)
- ✅ Red Hat support and security updates

### Alternative Jenkinsfiles

| File | Description | Use Case |
|------|-------------|----------|
| `Jenkinsfile` | Original pipeline | Standard deployment |
| `Jenkinsfile-buildconfig` | **Recommended** - Auto-creates UBI Dockerfile | Avoids certificate issues |
| `Jenkinsfile-fixed.groovy` | Kaniko-based (requires anyuid SCC) | Not recommended |

**To use the recommended pipeline:**
```bash
# In Jenkins, configure pipeline to use:
Jenkinsfile-buildconfig
```

### Detailed Documentation

For comprehensive analysis and alternative solutions:
- **`SOLUTION-SUMMARY.md`** - Complete overview of all three build failures
- **`QUICK-FIX-CERTIFICATE.md`** - Quick reference for certificate issues
- **`IMAGE-BUILD-SOLUTIONS.md`** - Detailed technical analysis
- **`Dockerfile.ubi`** - Ready-to-use OpenShift-optimized Dockerfile

---

## File Structure

```
jenkins-openshift/
├── Jenkinsfile                           # ✅ Jib-based pipeline (recommended)
├── JIB-MIGRATION.md                      # Jib migration guide
├── pod-template-agent.yaml               # Pod template reference
├── agent-rbac.yaml                       # RBAC configuration
├── task.plan                             # Execution checklist
├── README.md                             # This file
├── openshift/
│   └── pvc-jenkins-workspace.yaml        # Shared storage
└── legacy/ (deprecated)
    ├── Jenkinsfile-buildconfig           # BuildConfig-based pipeline
    ├── Jenkinsfile-fixed.groovy          # Kaniko-based pipeline
    ├── Dockerfile.ubi                    # OpenShift Dockerfile
    ├── buildconfig-petclinic.yaml        # BuildConfig manifest
    ├── SOLUTION-SUMMARY.md               # Build solutions overview
    ├── QUICK-FIX-CERTIFICATE.md          # Certificate fix guide
    └── IMAGE-BUILD-SOLUTIONS.md          # Detailed analysis
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
