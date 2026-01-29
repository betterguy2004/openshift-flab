# Helm Charts Customization Summary

Đã custom lại các Helm charts dựa trên các file K8s manifest trong thư mục `k8s/`.

## 📋 Tổng quan thay đổi

### 1. **Spring Petclinic Application** (`helm/app/`)

#### Values đã custom ([values.yaml](file:///D:/Openshift-lab/spring-petclinic-main/spring-petclinic-main/helm/app/values.yaml))

| Thuộc tính | Giá trị | Mô tả |
|-----------|---------|-------|
| `image.repository` | `dsyer/petclinic` | Image của Spring Petclinic |
| `image.tag` | `""` (latest) | Sử dụng tag mới nhất |
| `service.type` | `NodePort` | Expose qua NodePort |
| `service.port` | `80` | Port của service |
| `service.targetPort` | `8080` | Port của container |
| `containerPort` | `8080` | Container listening port |

#### Environment Variables

```yaml
env:
  - name: SPRING_PROFILES_ACTIVE
    value: postgres
  - name: SERVICE_BINDING_ROOT
    value: /bindings
```

#### Health Probes

- **Liveness Probe**: `GET /livez` (port: http)
- **Readiness Probe**: `GET /readyz` (port: http)

#### Volume Mounts (Database Binding)

```yaml
volumes:
  - name: binding
    projected:
      sources:
        - secret:
            name: demo-db

volumeMounts:
  - name: binding
    mountPath: /bindings/secret
    readOnly: true
```

---

### 2. **PostgreSQL Database** (`helm/postgresql/`)

#### Values đã custom ([values.yaml](file:///D:/Openshift-lab/spring-petclinic-main/spring-petclinic-main/helm/postgresql/values.yaml))

| Thuộc tính | Giá trị | Mô tả |
|-----------|---------|-------|
| `image.repository` | `postgres` | Official PostgreSQL image |
| `image.tag` | `"18.1"` | PostgreSQL version 18.1 |
| `service.type` | `ClusterIP` | Internal service only |
| `service.port` | `5432` | PostgreSQL default port |
| `containerPort` | `5432` | Container listening port |

#### Database Configuration

```yaml
postgresql:
  database: petclinic
  username: user
  password: pass
  type: postgresql
  provider: postgresql
```

#### Secret Configuration

```yaml
secret:
  name: demo-db
  type: servicebinding.io/postgresql
  create: true
```

Secret sẽ chứa các key sau:
- `type`: "postgresql"
- `provider`: "postgresql"
- `host`: "demo-db" (service name)
- `port`: "5432"
- `database`: "petclinic"
- `username`: "user"
- `password`: "pass"

#### Environment Variables

Credentials được inject từ Secret:

```yaml
env:
  - name: POSTGRES_USER
    valueFrom:
      secretKeyRef:
        name: demo-db
        key: username
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: demo-db
        key: password
  - name: POSTGRES_DB
    valueFrom:
      secretKeyRef:
        name: demo-db
        key: database
```

#### Health Probes

- **Liveness Probe**: TCP check on port `postgresql`
- **Readiness Probe**: TCP check on port `postgresql`
- **Startup Probe**: TCP check on port `postgresql`

---

## 🔧 Template Changes

### Application Templates

#### [deployment.yaml](file:///D:/Openshift-lab/spring-petclinic-main/spring-petclinic-main/helm/app/templates/deployment.yaml)

✅ Thêm support cho environment variables:
```yaml
{{- with .Values.env }}
env:
  {{- toYaml . | nindent 12 }}
{{- end }}
```

✅ Sửa containerPort sử dụng `containerPort` thay vì `service.port`:
```yaml
containerPort: {{ .Values.containerPort | default 8080 }}
```

### PostgreSQL Templates

#### [deployment.yaml](file:///D:/Openshift-lab/spring-petclinic-main/spring-petclinic-main/helm/postgresql/templates/deployment.yaml)

✅ Thêm support cho environment variables
✅ Thêm support cho startup probe
✅ Đổi port name từ `http` → `postgresql`
✅ Sửa containerPort sử dụng `containerPort` value

#### [service.yaml](file:///D:/Openshift-lab/spring-petclinic-main/spring-petclinic-main/helm/postgresql/templates/service.yaml)

✅ Đổi targetPort từ `http` → `postgresql`
✅ Đổi port name từ `http` → `postgresql`

#### [secret.yaml](file:///D:/Openshift-lab/spring-petclinic-main/spring-petclinic-main/helm/postgresql/templates/secret.yaml) ⭐ NEW

✅ Tạo mới Secret template với service binding format
✅ Auto-generate database connection details
✅ Support conditional creation với `.Values.secret.create`

---

## 🚀 Cách sử dụng

### 1. Deploy PostgreSQL Database

```bash
cd D:\Openshift-lab\spring-petclinic-main\spring-petclinic-main\helm\postgresql

# Install chart
helm install demo-db . -n petclinic-hungpq52

# Hoặc với custom values
helm install demo-db . -n petclinic-hungpq52 \
  --set postgresql.password=mySecurePassword
```

### 2. Deploy Spring Petclinic Application

```bash
cd D:\Openshift-lab\spring-petclinic-main\spring-petclinic-main\helm\app

# Install chart
helm install petclinic . -n petclinic-hungpq52

# Hoặc với custom image
helm install petclinic . -n petclinic-hungpq52 \
  --set image.repository=nexus.apps.s68/petclinic \
  --set image.tag=latest
```

### 3. Verify Deployment

```bash
# Check pods
oc get pods -n petclinic-hungpq52

# Check services
oc get svc -n petclinic-hungpq52

# Check secrets
oc get secret demo-db -n petclinic-hungpq52 -o yaml

# Get NodePort
oc get svc petclinic -n petclinic-hungpq52
```

---

## 📝 So sánh với K8s Manifests

### Petclinic App

| Aspect | K8s Manifest | Helm Chart |
|--------|--------------|------------|
| Image | `dsyer/petclinic` | ✅ Same |
| Service Type | `NodePort` | ✅ Same |
| Ports | 80 → 8080 | ✅ Same |
| Env Vars | SPRING_PROFILES_ACTIVE, SERVICE_BINDING_ROOT | ✅ Same |
| Health Probes | /livez, /readyz | ✅ Same |
| Volume Mount | /bindings/secret | ✅ Same |

### PostgreSQL

| Aspect | K8s Manifest | Helm Chart |
|--------|--------------|------------|
| Image | `postgres:18.1` | ✅ Same |
| Service Type | `ClusterIP` | ✅ Same |
| Port | 5432 | ✅ Same |
| Secret | demo-db (servicebinding.io/postgresql) | ✅ Same |
| Env Vars | From secret | ✅ Same |
| Health Probes | TCP socket | ✅ Same |
| Startup Probe | TCP socket | ✅ Same |

---

## ⚙️ Customization Options

### Override values khi install

```bash
# Custom database credentials
helm install demo-db ./postgresql \
  --set postgresql.database=mydb \
  --set postgresql.username=admin \
  --set postgresql.password=secret123

# Custom app image
helm install petclinic ./app \
  --set image.repository=myregistry/petclinic \
  --set image.tag=v1.0.0

# Enable ingress
helm install petclinic ./app \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=petclinic.example.com
```

### Tạo custom values file

```bash
# Create custom-values.yaml
cat > custom-values.yaml <<EOF
image:
  repository: nexus.apps.s68/petclinic
  tag: "1.0.0"

service:
  type: ClusterIP

ingress:
  enabled: true
  hosts:
    - host: petclinic.apps.s68
      paths:
        - path: /
          pathType: Prefix
EOF

# Install with custom values
helm install petclinic ./app -f custom-values.yaml
```

---

## 🔍 Troubleshooting

### Check Secret được tạo đúng chưa

```bash
oc get secret demo-db -o jsonpath='{.data.database}' | base64 -d
oc get secret demo-db -o jsonpath='{.data.username}' | base64 -d
oc get secret demo-db -o jsonpath='{.data.password}' | base64 -d
```

### Check Pod logs

```bash
# PostgreSQL logs
oc logs -f deployment/demo-db

# Petclinic logs
oc logs -f deployment/petclinic
```

### Verify database connection

```bash
# Port-forward to PostgreSQL
oc port-forward svc/demo-db 5432:5432

# Connect using psql
psql -h localhost -U user -d petclinic
```

---

## 📚 References

- [K8s Manifests](file:///D:/Openshift-lab/spring-petclinic-main/spring-petclinic-main/k8s/)
  - [petclinic.yml](file:///D:/Openshift-lab/spring-petclinic-main/spring-petclinic-main/k8s/petclinic.yml)
  - [db.yml](file:///D:/Openshift-lab/spring-petclinic-main/spring-petclinic-main/k8s/db.yml)
- [Helm Charts](file:///D:/Openshift-lab/spring-petclinic-main/spring-petclinic-main/helm/)
  - [app/values.yaml](file:///D:/Openshift-lab/spring-petclinic-main/spring-petclinic-main/helm/app/values.yaml)
  - [postgresql/values.yaml](file:///D:/Openshift-lab/spring-petclinic-main/spring-petclinic-main/helm/postgresql/values.yaml)
