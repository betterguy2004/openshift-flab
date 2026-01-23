# Decision Tree: Which Image Build Solution?

```
START: I need to build container images in OpenShift Jenkins pipeline
│
├─ Q1: Do you have cluster-admin privileges?
│  │
│  ├─ YES ──┐
│  │        │
│  └─ NO ───┼─→ Q2: Can you modify the Dockerfile?
│           │    │
│           │    ├─ YES → ✅ USE SOLUTION 1: BuildConfig + Red Hat UBI
│           │    │         (Fastest, no admin needed, production-ready)
│           │    │
│           │    └─ NO ──→ ✅ USE SOLUTION 3: Import Base Image
│           │              (Import once, then use from internal registry)
│           │
│           └─→ Q3: Is this for production?
│               │
│               ├─ YES → ✅ USE SOLUTION 1: BuildConfig + Red Hat UBI
│               │         (Best security, Red Hat supported)
│               │
│               └─ NO ──→ ⚠️  USE SOLUTION 2: Insecure Registry
│                         (Dev/test only, requires cluster-admin)
```

---

## Solution Comparison Matrix

| Criteria | Solution 1: UBI | Solution 2: Insecure | Solution 3: Import |
|----------|----------------|---------------------|-------------------|
| **Cluster Admin Required** | ❌ No | ✅ Yes | ❌ No |
| **Time to Implement** | ⚡ 2 min | ⏱️ 15-20 min | ⏱️ 5 min |
| **Security Level** | 🔒 High | ⚠️ Low | 🔒 High |
| **Production Ready** | ✅ Yes | ❌ No | ✅ Yes |
| **Red Hat Supported** | ✅ Yes | ❌ No | ✅ Yes |
| **Modify Dockerfile** | ✅ Yes | ❌ No | ✅ Yes |
| **One-time Setup** | ❌ No | ✅ Yes | ✅ Yes |
| **Works Offline** | ✅ Yes | ❌ No | ✅ Yes |

---

## Recommendation by Scenario

### Scenario 1: New Project (Greenfield)
**Recommended:** ✅ **Solution 1 - BuildConfig + Red Hat UBI**

**Why:**
- Start with best practices from day one
- No technical debt
- Production-ready from the start
- Red Hat support

**Action:**
```bash
# Use the ready-made Jenkinsfile
Jenkinsfile-buildconfig
```

---

### Scenario 2: Existing Project (Can't Change Dockerfile)
**Recommended:** ✅ **Solution 3 - Import Base Image**

**Why:**
- Keep existing Dockerfile unchanged
- No cluster-admin needed
- One-time setup

**Action:**
```bash
oc import-image eclipse-temurin:17-jre \
  --from=docker.io/eclipse-temurin:17-jre-jammy \
  --confirm \
  -n petclinic-hungpq52

# Update Dockerfile to use internal registry
FROM image-registry.openshift-image-registry.svc:5000/petclinic-hungpq52/eclipse-temurin:17-jre
```

---

### Scenario 3: Quick Dev/Test (Have Cluster Admin)
**Recommended:** ⚠️ **Solution 2 - Insecure Registry**

**Why:**
- Fastest if you have admin access
- No code changes needed
- Good for temporary testing

**Warning:** ⚠️ **DO NOT USE IN PRODUCTION**

**Action:**
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

---

### Scenario 4: Multi-tenant Cluster (Strict Security)
**Recommended:** ✅ **Solution 1 - BuildConfig + Red Hat UBI**

**Why:**
- No cluster-wide configuration changes
- Namespace-isolated
- Meets security compliance
- Auditable

**Action:**
```bash
# Use Jenkinsfile-buildconfig
# It creates UBI-based Dockerfile automatically
```

---

## Quick Start Guide by Solution

### ✅ Solution 1: BuildConfig + Red Hat UBI (RECOMMENDED)

**Prerequisites:** None (works out of the box)

**Steps:**
1. Configure Jenkins to use `Jenkinsfile-buildconfig`
2. Run the pipeline
3. Done! ✅

**Time:** 2 minutes

---

### ⚠️ Solution 2: Insecure Registry (DEV ONLY)

**Prerequisites:** Cluster-admin access

**Steps:**
1. Run the `oc patch` command (see QUICK-FIX-CERTIFICATE.md)
2. Wait for Machine Config Pools to update (15-20 min)
3. Run your existing pipeline
4. Done! ✅

**Time:** 15-20 minutes

---

### ✅ Solution 3: Import Base Image

**Prerequisites:** None

**Steps:**
1. Import base image: `oc import-image ...`
2. Update Dockerfile to use internal registry
3. Run your pipeline
4. Done! ✅

**Time:** 5 minutes

---

## Why NOT Buildah or Kaniko in Pods?

### Buildah in Standard Pod
```
❌ Requires: User namespaces (CLONE_NEWUSER)
❌ Blocked by: OpenShift Security Context Constraints
❌ Workaround: None (fundamentally incompatible)
✅ Alternative: Use BuildConfig (runs Buildah in privileged build pod)
```

### Kaniko in Standard Pod
```
❌ Requires: Root filesystem modifications
❌ Blocked by: OpenShift SCC (even with runAsUser: 0)
⚠️ Workaround: Grant anyuid or privileged SCC (SECURITY RISK)
✅ Alternative: Use BuildConfig (native OpenShift solution)
```

### BuildConfig (RECOMMENDED)
```
✅ Uses: Buildah internally with proper privileges
✅ Runs in: Dedicated build pods with correct SCCs
✅ Integrated: OpenShift RBAC, security, networking
✅ Supported: Red Hat official solution
```

---

## Common Questions

### Q: Why does BuildConfig work but Buildah in pod doesn't?
**A:** BuildConfig creates **dedicated build pods** with proper Security Context Constraints. Your Jenkins agent pod runs with restricted SCCs for security.

### Q: Can I use Kaniko if I grant anyuid SCC?
**A:** Yes, but **DON'T**. This is a security risk in multi-tenant clusters. Use BuildConfig instead.

### Q: What if I must use eclipse-temurin image?
**A:** Use **Solution 3** (Import Base Image). Import it once to OpenShift's internal registry, then reference it from there.

### Q: Is Red Hat UBI as good as eclipse-temurin?
**A:** Yes! Both use OpenJDK. UBI advantages:
- ✅ Optimized for OpenShift
- ✅ Red Hat security updates
- ✅ Smaller image size (runtime-only)
- ✅ Better container support

### Q: Can I use Solution 2 in production?
**A:** **NO!** Insecure registries bypass TLS verification cluster-wide. Use Solution 1 or 3 for production.

---

## Implementation Checklist

### Before You Start
- [ ] Identify your scenario (see above)
- [ ] Check if you have cluster-admin access
- [ ] Decide if you can modify Dockerfile
- [ ] Choose your solution

### Solution 1: BuildConfig + UBI
- [ ] Configure Jenkins to use `Jenkinsfile-buildconfig`
- [ ] Run pipeline
- [ ] Verify deployment
- [ ] Update documentation

### Solution 2: Insecure Registry
- [ ] Confirm this is dev/test only
- [ ] Get cluster-admin access
- [ ] Run `oc patch` command
- [ ] Wait for MCP update
- [ ] Test pipeline
- [ ] Document the configuration

### Solution 3: Import Base Image
- [ ] Run `oc import-image` command
- [ ] Update Dockerfile
- [ ] Commit changes
- [ ] Run pipeline
- [ ] Verify deployment

---

## Success Criteria

After implementing your chosen solution, verify:

```bash
# Build succeeds
oc get builds -n petclinic-hungpq52
# Should show: STATUS: Complete

# Image is pushed
oc get is -n petclinic-hungpq52
# Should show your image

# Deployment is running
oc get pods -n petclinic-hungpq52
# Should show: STATUS: Running

# Application is accessible
ROUTE=$(oc get route petclinic -n petclinic-hungpq52 -o jsonpath='{.spec.host}')
curl -I http://${ROUTE}
# Should return: HTTP/1.1 200 OK
```

---

## Need Help?

1. **Certificate errors?** → See `QUICK-FIX-CERTIFICATE.md`
2. **Detailed analysis?** → See `IMAGE-BUILD-SOLUTIONS.md`
3. **Complete overview?** → See `SOLUTION-SUMMARY.md`
4. **Ready-to-use Dockerfile?** → See `Dockerfile.ubi`

---

**TL;DR:** Use `Jenkinsfile-buildconfig` and you're done! ✅
