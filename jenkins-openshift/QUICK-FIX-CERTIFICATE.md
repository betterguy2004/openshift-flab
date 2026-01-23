# QUICK FIX: Certificate Error Solution

## Problem
BuildConfig fails with: `x509: certificate signed by unknown authority`

## Root Cause
The base image `eclipse-temurin:17-jre-jammy` is pulled from CloudFlare R2 CDN, which uses a certificate not trusted by OpenShift.

---

## ✅ SOLUTION 1: Use Red Hat UBI (RECOMMENDED - NO CLUSTER ADMIN NEEDED)

This is the **fastest and safest** solution. Red Hat Universal Base Images are already trusted by OpenShift.

### Step 1: Copy the UBI Dockerfile to your Spring Petclinic directory

```bash
# Navigate to your Spring Petclinic directory
cd d:\Openshift-lab\spring-petclinic-main\spring-petclinic-main

# Copy the UBI Dockerfile
copy d:\Openshift-lab\jenkins-openshift\Dockerfile.ubi Dockerfile
```

Or manually create this `Dockerfile`:

```dockerfile
FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:latest

COPY target/*.jar /deployments/app.jar

USER 185

EXPOSE 8080

ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

ENTRYPOINT ["java", "-jar", "/deployments/app.jar"]
```

### Step 2: Use the new Jenkinsfile

```bash
# In Jenkins, point your pipeline to:
d:\Openshift-lab\jenkins-openshift\Jenkinsfile-buildconfig
```

### Step 3: Run the pipeline

The pipeline will:
1. ✅ Checkout Spring Petclinic
2. ✅ Build with Maven
3. ✅ Create a Dockerfile using Red Hat UBI (no certificate issues)
4. ✅ Build image with BuildConfig
5. ✅ Push to Nexus
6. ✅ Deploy to OpenShift

**This solution requires NO cluster-admin privileges!**

---

## ✅ SOLUTION 2: Configure Insecure Registry (REQUIRES CLUSTER-ADMIN)

If you have cluster-admin access and want to keep using `eclipse-temurin` images:

### Step 1: Add insecure registry configuration

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

### Step 2: Wait for nodes to update (5-15 minutes)

```bash
watch oc get mcp
```

Wait until all Machine Config Pools show `UPDATED=True`.

### Step 3: Run your pipeline

Now BuildConfig can pull from CloudFlare R2 without certificate verification.

---

## ✅ SOLUTION 3: Import Base Image to OpenShift Registry

Import the base image once, then use it from OpenShift's internal registry:

### Step 1: Import the image

```bash
oc import-image eclipse-temurin:17-jre \
  --from=docker.io/eclipse-temurin:17-jre-jammy \
  --confirm \
  -n petclinic-hungpq52
```

### Step 2: Update your Dockerfile

```dockerfile
FROM image-registry.openshift-image-registry.svc:5000/petclinic-hungpq52/eclipse-temurin:17-jre

COPY target/*.jar /deployments/app.jar

USER 185

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/deployments/app.jar"]
```

### Step 3: Run the pipeline

Now BuildConfig pulls from OpenShift's internal registry (no external certificate issues).

---

## Comparison

| Solution | Cluster Admin Required | Time to Implement | Recommendation |
|----------|----------------------|-------------------|----------------|
| **Solution 1: Red Hat UBI** | ❌ No | ⚡ 2 minutes | ✅ **BEST** |
| **Solution 2: Insecure Registry** | ✅ Yes | ⏱️ 15-20 minutes | ⚠️ Dev only |
| **Solution 3: Import Image** | ❌ No | ⏱️ 5 minutes | ✅ Good |

---

## Next Steps

### If you choose Solution 1 (Recommended):

1. **Copy the Jenkinsfile**:
   ```bash
   copy d:\Openshift-lab\jenkins-openshift\Jenkinsfile-buildconfig d:\Openshift-lab\jenkins-openshift\Jenkinsfile
   ```

2. **Update your Jenkins pipeline** to use this Jenkinsfile

3. **Run the pipeline** - it will automatically create the Dockerfile with Red Hat UBI

### If you choose Solution 2:

1. Ask your cluster administrator to run the `oc patch` command
2. Wait for Machine Config Pools to update
3. Use your existing Jenkinsfile

### If you choose Solution 3:

1. Run the `oc import-image` command
2. Update your Dockerfile in Spring Petclinic directory
3. Run your existing pipeline

---

## Testing

After implementing any solution, test with:

```bash
# Start a test build manually
oc start-build petclinic --from-dir=. --follow -n petclinic-hungpq52

# Check build logs
oc logs -f bc/petclinic -n petclinic-hungpq52
```

If successful, you'll see:
```
✅ Successfully pushed image
```

---

## Why BuildConfig is Better Than Buildah/Kaniko in Pods

| Tool | Issue | Why BuildConfig Wins |
|------|-------|---------------------|
| **Buildah** | Needs `CLONE_NEWUSER` (user namespaces) | BuildConfig runs in privileged build pods |
| **Kaniko** | Needs `anyuid` SCC, filesystem permissions | BuildConfig has proper SCCs automatically |
| **BuildConfig** | ✅ Native OpenShift, secure, integrated | ✅ **Recommended by Red Hat** |

---

## Support

If you encounter issues:

1. Check build logs: `oc logs -f bc/petclinic -n petclinic-hungpq52`
2. Check pod logs: `oc logs -f deployment/petclinic -n petclinic-hungpq52`
3. Verify BuildConfig: `oc describe bc petclinic -n petclinic-hungpq52`
4. Check RBAC: `oc get rolebinding -n petclinic-hungpq52 | grep jenkins`
