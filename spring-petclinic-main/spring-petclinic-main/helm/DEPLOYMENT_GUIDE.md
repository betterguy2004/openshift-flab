# Quick Deployment Guide - Spring Petclinic on OpenShift

## Prerequisites

```bash
# Ensure you're in the correct namespace
oc project petclinic-hungpq52

# Or create if it doesn't exist
oc new-project petclinic-hungpq52
```

## Option 1: Deploy with Helm (Recommended)

### Step 1: Deploy PostgreSQL

```bash
cd D:\Openshift-lab\spring-petclinic-main\spring-petclinic-main\helm\postgresql

# Install PostgreSQL with default values
helm install demo-db . -n petclinic-hungpq52

# Verify installation
helm list -n petclinic-hungpq52
oc get pods -n petclinic-hungpq52 -l app.kubernetes.io/name=postgresql
```

### Step 2: Deploy Petclinic Application

```bash
cd D:\Openshift-lab\spring-petclinic-main\spring-petclinic-main\helm\app

# Install Petclinic app
helm install petclinic . -n petclinic-hungpq52

# Verify installation
oc get pods -n petclinic-hungpq52 -l app.kubernetes.io/name=app
oc get svc -n petclinic-hungpq52
```

### Step 3: Access the Application

```bash
# Get the NodePort
oc get svc petclinic -n petclinic-hungpq52

# Access via browser
# http://<node-ip>:<node-port>
```

---

## Option 2: Deploy with K8s Manifests

### Step 1: Deploy Database

```bash
cd D:\Openshift-lab\spring-petclinic-main\spring-petclinic-main\k8s

# Apply database manifest
oc apply -f db.yml -n petclinic-hungpq52

# Wait for database to be ready
oc wait --for=condition=ready pod -l app=demo-db -n petclinic-hungpq52 --timeout=120s
```

### Step 2: Deploy Application

```bash
# Apply application manifest
oc apply -f petclinic.yml -n petclinic-hungpq52

# Wait for app to be ready
oc wait --for=condition=ready pod -l app=petclinic -n petclinic-hungpq52 --timeout=120s
```

---

## Option 3: Deploy with Custom Image (CI/CD)

If you've built a custom image using Jenkins:

```bash
cd D:\Openshift-lab\spring-petclinic-main\spring-petclinic-main\helm

# Create custom values file
cat > custom-values.yaml <<EOF
image:
  repository: nexus.apps.s68/petclinic
  tag: latest
  pullPolicy: Always

service:
  type: ClusterIP

# Optional: Create OpenShift Route
route:
  enabled: true
  host: petclinic.apps.s68
EOF

# Deploy PostgreSQL (same as Option 1)
helm install demo-db ./postgresql -n petclinic-hungpq52

# Deploy Petclinic with custom image
helm install petclinic ./app -n petclinic-hungpq52 -f custom-values.yaml
```

---

## Verification Commands

### Check All Resources

```bash
# List all resources
oc get all -n petclinic-hungpq52

# Check pods status
oc get pods -n petclinic-hungpq52 -w

# Check services
oc get svc -n petclinic-hungpq52

# Check secrets
oc get secrets -n petclinic-hungpq52
```

### Check Database Secret

```bash
# View secret details
oc get secret demo-db -n petclinic-hungpq52 -o yaml

# Decode secret values
echo "Database: $(oc get secret demo-db -n petclinic-hungpq52 -o jsonpath='{.data.database}' | base64 -d)"
echo "Username: $(oc get secret demo-db -n petclinic-hungpq52 -o jsonpath='{.data.username}' | base64 -d)"
echo "Host: $(oc get secret demo-db -n petclinic-hungpq52 -o jsonpath='{.data.host}' | base64 -d)"
echo "Port: $(oc get secret demo-db -n petclinic-hungpq52 -o jsonpath='{.data.port}' | base64 -d)"
```

### Check Application Logs

```bash
# PostgreSQL logs
oc logs -f deployment/demo-db -n petclinic-hungpq52

# Petclinic logs
oc logs -f deployment/petclinic -n petclinic-hungpq52

# Check for errors
oc logs deployment/petclinic -n petclinic-hungpq52 | grep -i error
```

### Test Database Connection

```bash
# Port-forward to PostgreSQL
oc port-forward svc/demo-db 5432:5432 -n petclinic-hungpq52

# In another terminal, test connection
psql -h localhost -U user -d petclinic
# Password: pass

# Or use oc exec
oc exec -it deployment/demo-db -n petclinic-hungpq52 -- psql -U user -d petclinic -c "\dt"
```

### Test Application Health

```bash
# Port-forward to application
oc port-forward svc/petclinic 8080:80 -n petclinic-hungpq52

# Test health endpoints
curl http://localhost:8080/livez
curl http://localhost:8080/readyz

# Or from within the cluster
oc exec -it deployment/petclinic -n petclinic-hungpq52 -- curl localhost:8080/livez
```

---

## Upgrade/Update Deployments

### Upgrade with Helm

```bash
# Update PostgreSQL
helm upgrade demo-db ./postgresql -n petclinic-hungpq52 \
  --set postgresql.password=newPassword

# Update Petclinic
helm upgrade petclinic ./app -n petclinic-hungpq52 \
  --set image.tag=v2.0.0

# Rollback if needed
helm rollback petclinic -n petclinic-hungpq52
helm rollback demo-db -n petclinic-hungpq52
```

### Update with K8s Manifests

```bash
# Edit and reapply
oc apply -f db.yml -n petclinic-hungpq52
oc apply -f petclinic.yml -n petclinic-hungpq52

# Force rollout
oc rollout restart deployment/petclinic -n petclinic-hungpq52
oc rollout restart deployment/demo-db -n petclinic-hungpq52
```

---

## Cleanup

### Uninstall Helm Releases

```bash
# Uninstall application
helm uninstall petclinic -n petclinic-hungpq52

# Uninstall database
helm uninstall demo-db -n petclinic-hungpq52

# Verify cleanup
helm list -n petclinic-hungpq52
```

### Delete K8s Resources

```bash
# Delete application
oc delete -f petclinic.yml -n petclinic-hungpq52

# Delete database
oc delete -f db.yml -n petclinic-hungpq52

# Or delete everything in namespace
oc delete all --all -n petclinic-hungpq52
```

### Delete Namespace (Complete Cleanup)

```bash
# WARNING: This deletes everything
oc delete project petclinic-hungpq52
```

---

## Troubleshooting

### Pod Not Starting

```bash
# Describe pod to see events
oc describe pod <pod-name> -n petclinic-hungpq52

# Check pod logs
oc logs <pod-name> -n petclinic-hungpq52

# Check previous logs if pod restarted
oc logs <pod-name> -n petclinic-hungpq52 --previous
```

### ImagePullBackOff

```bash
# Check image pull secrets
oc get secrets -n petclinic-hungpq52

# Verify image exists
oc run test --image=dsyer/petclinic --dry-run=client -o yaml

# Check service account
oc get sa -n petclinic-hungpq52
```

### Database Connection Issues

```bash
# Verify secret exists and has correct values
oc get secret demo-db -n petclinic-hungpq52 -o yaml

# Check if database pod is running
oc get pods -l app=demo-db -n petclinic-hungpq52

# Test connection from app pod
oc exec -it deployment/petclinic -n petclinic-hungpq52 -- \
  sh -c 'nc -zv demo-db 5432'
```

### Application Not Accessible

```bash
# Check service
oc get svc petclinic -n petclinic-hungpq52

# Check endpoints
oc get endpoints petclinic -n petclinic-hungpq52

# Create route if needed (OpenShift)
oc expose svc/petclinic -n petclinic-hungpq52
oc get route -n petclinic-hungpq52
```

---

## Integration with Jenkins CI/CD

See [jenkins-openshift](file:///D:/Openshift-lab/jenkins-openshift/) for CI/CD pipeline configuration.

### Build and Deploy Flow

1. Jenkins builds the application using Maven
2. Creates Docker image using BuildConfig
3. Pushes to Nexus registry
4. Deploys using Helm or `oc new-app`

### Example Jenkins Integration

```groovy
stage('Deploy with Helm') {
    container('jnlp') {
        sh """
            # Deploy PostgreSQL (if not exists)
            helm upgrade --install demo-db ./helm/postgresql \
                -n ${APP_NS} \
                --wait

            # Deploy Application
            helm upgrade --install petclinic ./helm/app \
                -n ${APP_NS} \
                --set image.repository=${NEXUS_REGISTRY}/${IMAGE_NAME} \
                --set image.tag=${IMAGE_TAG} \
                --wait
        """
    }
}
```
