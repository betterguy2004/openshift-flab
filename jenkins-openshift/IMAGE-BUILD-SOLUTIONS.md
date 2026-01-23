# Image Build Solutions for OpenShift Jenkins Pipeline

## Problem Summary

You encountered three different errors when trying to build container images in OpenShift:

1. **Buildah**: `Error during unshare(CLONE_NEWUSER): Function not implemented`
2. **Kaniko**: `error removing bin to make way for new symlink: unlinkat //bin/sh: permission denied`
3. **BuildConfig**: `x509: certificate signed by unknown authority`

## Root Causes

### Buildah Issue
- **Cause**: Buildah requires user namespace support (`CLONE_NEWUSER`) which is blocked by OpenShift's Security Context Constraints (SCC)
- **Why it fails**: Standard pods cannot create user namespaces for security reasons

### Kaniko Issue
- **Cause**: Kaniko tries to modify root filesystem paths even with `runAsUser: 0`
- **Why it fails**: OpenShift SCC prevents certain filesystem modifications even for root user

### BuildConfig Issue
- **Cause**: BuildConfig cannot verify TLS certificates from external registries (CloudFlare R2 CDN)
- **Why it fails**: The base image registry uses certificates not in OpenShift's trust store

---

## RECOMMENDED SOLUTION: Fix BuildConfig (Option 3)

BuildConfig is the **official OpenShift-native** way to build images and aligns with your project standards.

### Solution 3A: Configure Insecure Registry (Quick Fix)

This tells OpenShift to skip TLS verification for specific registries.

#### Step 1: Check Current Image Registry Configuration

```bash
oc get image.config.openshift.io/cluster -o yaml
```

#### Step 2: Add Insecure Registry Configuration

You need **cluster-admin** privileges for this. If you don't have it, ask your cluster administrator to run:

```bash
oc patch image.config.openshift.io/cluster --type=merge -p '
{
  "spec": {
    "registrySources": {
      "insecureRegistries": [
        "docker-images-prod.6aa30f8b08e16409b46e0173d6de2f56.r2.cloudflarestorage.com"
      ]
    }
  }
}'
```

**Note**: This affects the entire cluster. For production, use Solution 3B instead.

#### Step 3: Rebuild

```bash
oc start-build petclinic --from-dir=. --follow -n petclinic-hungpq52
```

---

### Solution 3B: Add Custom CA Certificate (Production-Ready)

This is the **proper production solution** - add the registry's CA certificate to OpenShift's trust store.

#### Step 1: Get the CA Certificate

```bash
# Extract the CA certificate from the registry
openssl s_client -showcerts -connect docker-images-prod.6aa30f8b08e16409b46e0173d6de2f56.r2.cloudflarestorage.com:443 </dev/null 2>/dev/null | openssl x509 -outform PEM > cloudflare-r2-ca.crt
```

#### Step 2: Create ConfigMap with CA Certificate

```bash
oc create configmap cloudflare-r2-ca \
  --from-file=ca-bundle.crt=cloudflare-r2-ca.crt \
  -n openshift-config
```

#### Step 3: Update Cluster Image Configuration

```bash
oc patch image.config.openshift.io/cluster --type=merge -p '
{
  "spec": {
    "additionalTrustedCA": {
      "name": "cloudflare-r2-ca"
    }
  }
}'
```

#### Step 4: Wait for Machine Config Operator

The cluster will update all nodes. This takes 5-15 minutes:

```bash
watch oc get mcp
```

Wait until all Machine Config Pools show `UPDATED=True`.

#### Step 5: Rebuild

```bash
oc start-build petclinic --from-dir=. --follow -n petclinic-hungpq52
```

---

### Solution 3C: Use Different Base Image (Alternative)

If you cannot modify cluster configuration, use a base image from a trusted registry.

#### Option 1: Use Red Hat UBI (Universal Base Image)

Edit your `Dockerfile`:

```dockerfile
# Instead of: FROM eclipse-temurin:25-jdk-jammy
FROM registry.access.redhat.com/ubi9/openjdk-17:latest

COPY target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

#### Option 2: Use OpenShift Internal Registry

1. Import the base image to OpenShift:

```bash
oc import-image eclipse-temurin:17-jdk \
  --from=docker.io/library/eclipse-temurin:17-jdk \
  --confirm \
  -n petclinic-hungpq52
```

2. Update Dockerfile:

```dockerfile
FROM image-registry.openshift-image-registry.svc:5000/petclinic-hungpq52/eclipse-temurin:17-jdk

COPY target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

---

## Why NOT Use Buildah or Kaniko in Standard Pods?

### Buildah
- ❌ Requires privileged SCC or user namespace support
- ❌ Not supported in standard OpenShift pods
- ✅ **Already used internally by BuildConfig** with proper privileges

### Kaniko
- ❌ Requires extensive filesystem permissions
- ❌ Needs `anyuid` or `privileged` SCC
- ❌ Security risk in multi-tenant environments
- ⚠️  Works only with elevated privileges (not recommended)

### BuildConfig (RECOMMENDED)
- ✅ Native OpenShift solution
- ✅ Runs in privileged build pods automatically
- ✅ Integrated with OpenShift RBAC and SCC
- ✅ Supports all Dockerfile features
- ✅ Aligns with your project standards

---

## Implementation Steps for Your Pipeline

### Step 1: Choose a Solution

**For Development/Testing**: Use Solution 3A (Insecure Registry)
**For Production**: Use Solution 3B (CA Certificate)
**If No Cluster Admin**: Use Solution 3C (Different Base Image)

### Step 2: Update Jenkinsfile

Use the existing BuildConfig approach from your project standards:

```groovy
stage('Build & Push Image') {
  steps {
    container('jnlp') {
      sh """
        # Ensure BuildConfig exists
        oc get bc petclinic -n ${APP_NS} || \
          oc apply -f openshift/buildconfig-petclinic.yaml
        
        # Start build from current directory
        oc start-build petclinic \
          --from-dir=. \
          --follow \
          -n ${APP_NS}
        
        echo "✅ Image built and pushed via BuildConfig"
      """
    }
  }
}
```

### Step 3: Verify

```bash
# Check build logs
oc logs -f bc/petclinic -n petclinic-hungpq52

# Verify image was pushed
oc get builds -n petclinic-hungpq52
```

---

## Quick Comparison

| Tool | Pros | Cons | Recommendation |
|------|------|------|----------------|
| **BuildConfig** | Native, secure, integrated | Requires cluster config for certs | ✅ **USE THIS** |
| **Buildah** | Powerful, rootless capable | Needs user namespaces (blocked) | ❌ Won't work in pods |
| **Kaniko** | Daemonless, popular | Needs elevated SCC | ⚠️  Security risk |

---

## Next Steps

1. **Choose your solution** based on your access level (cluster-admin or not)
2. **Apply the fix** (insecure registry, CA cert, or different base image)
3. **Update your Jenkinsfile** to use BuildConfig
4. **Test the pipeline**

If you need cluster-admin access, contact your OpenShift administrator and share Solution 3A or 3B from this document.
