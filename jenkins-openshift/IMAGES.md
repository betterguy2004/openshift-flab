# Jenkins Images cho OpenShift - Quay.io Community Edition

## Tổng quan

Tài liệu này mô tả các community images từ **quay.io** được sử dụng cho Jenkins trên OpenShift Container Platform. Images này **không yêu cầu Red Hat subscription** và hoàn toàn miễn phí.

## Quay.io Community Images (Khuyến nghị)

### 1. **Jenkins Agent Base**
```bash
quay.io/openshift/origin-jenkins-agent-base:latest
```

Community version của Jenkins agent base image, bao gồm:
- JNLP agent để kết nối với Jenkins controller
- Java runtime  
- Git, tar, zip, nss
- OpenShift CLI (`oc`)

✅ **Miễn phí**, không cần Red Hat subscription  
✅ **Tương thích** với OpenShift  
✅ **Cập nhật thường xuyên** từ community

### 2. **OpenShift Origin CLI (kubectl/oc)**
```bash
quay.io/openshift/origin-cli:latest
```

Community image chứa cả `kubectl` và `oc` CLI tools.

### 3. **Maven (Docker Hub)**
```bash
maven:3.8-openjdk-11
```

Official Maven image từ Docker Hub, có sẵn Maven và OpenJDK.

## Alternative: Red Hat Official Images

Nếu bạn có Red Hat subscription, có thể sử dụng:

### 1. **Jenkins Controller**
```bash
registry.redhat.io/ocp-tools-4/jenkins-rhel8:latest
```

Đây là Jenkins controller image chính thức từ Red Hat, được optimize cho OpenShift.

### 2. **Jenkins Agent Base**
```bash
registry.redhat.io/ocp-tools-4/jenkins-agent-base-rhel8:latest
```

Đây là base image cho Jenkins agents, bao gồm:
- JNLP agent để kết nối với Jenkins controller
- Java runtime
- Các tools cơ bản

> **Lưu ý quan trọng**: Từ OpenShift 4.11+, Red Hat đã **deprecated** các specialized agent images như `jenkins-agent-maven` và `jenkins-agent-nodejs`. Thay vào đó, khuyến nghị sử dụng **sidecar pattern** với `jenkins-agent-base-rhel8`.

### 3. **OpenShift CLI (kubectl/oc)**
```bash
registry.redhat.io/openshift4/ose-cli:latest
```

Image chứa cả `kubectl` và `oc` CLI tools, dùng làm sidecar container.

### 4. **Red Hat UBI với OpenJDK**
```bash
# OpenJDK 11
registry.access.redhat.com/ubi8/openjdk-11:latest

# OpenJDK 17
registry.access.redhat.com/ubi8/openjdk-17:latest

# OpenJDK 21
registry.access.redhat.com/ubi9/openjdk-21:latest
```

Red Hat Universal Base Images (UBI) với OpenJDK, dùng cho Java builds.

> **Note**: Images này không có Maven pre-installed. Bạn cần:
> - Extend image và install Maven
> - Hoặc download Maven runtime trong pipeline script

## Sidecar Pattern

Khuyến nghị sử dụng **sidecar pattern** với quay.io community images:

```yaml
spec:
  containers:
  # JNLP agent container (bắt buộc)
  - name: jnlp
    image: quay.io/openshift/origin-jenkins-agent-base:latest
  
  # Sidecar containers cho tools cụ thể
  - name: kubectl
    image: quay.io/openshift/origin-cli:latest
    command: ['cat']
    tty: true
  
  - name: maven
    image: maven:3.8-openjdk-11
    command: ['cat']
    tty: true
```

## So sánh: Quay.io vs Red Hat Registry Images

| Purpose | Quay.io (Community) | Red Hat Registry (Subscription) |
|---------|-------------------|--------------------------------|
| Jenkins Agent Base | `quay.io/openshift/origin-jenkins-agent-base` | `registry.redhat.io/ocp-tools-4/jenkins-agent-base-rhel8` |
| OpenShift CLI | `quay.io/openshift/origin-cli` | `registry.redhat.io/openshift4/ose-cli` |
| Maven/Java | `maven:3.8-openjdk-11` | `registry.access.redhat.com/ubi8/openjdk-11` |

## Lợi ích của Quay.io Community Images

✅ **Miễn phí**: Không cần Red Hat subscription  
✅ **Tương thích**: Được thiết kế cho OpenShift/OKD  
✅ **Community support**: Cập nhật từ OpenShift community  
✅ **Public access**: Không cần authentication  
✅ **SCC**: Tương thích với Security Context Constraints  

## Lợi ích của Red Hat Registry Images (nếu có subscription)

✅ **Bảo mật**: Được scan và patch thường xuyên  
✅ **Hỗ trợ**: Có official support từ Red Hat  
✅ **Stability**: Tested với OpenShift releases  

## Authentication để Pull Images

### registry.redhat.io (Cần Red Hat subscription)

```bash
# Tạo pull secret
oc create secret docker-registry redhat-registry \
  --docker-server=registry.redhat.io \
  --docker-username='<username>' \
  --docker-password='<password>' \
  --docker-email='<email>' \
  -n jenkins

# Link secret với ServiceAccount
oc secrets link jenkins-agent redhat-registry --for=pull -n jenkins
```

### registry.access.redhat.com (Public, không cần auth)

UBI images từ `registry.access.redhat.com` là public và không cần authentication.

## Custom Agent Image Example

Nếu bạn muốn build custom agent image với Maven:

```dockerfile
FROM registry.redhat.io/ocp-tools-4/jenkins-agent-base-rhel8:latest

USER 0

# Install Maven
RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/3.8.8/binaries/apache-maven-3.8.8-bin.tar.gz \
  | tar xzf - -C /opt && \
  ln -s /opt/apache-maven-3.8.8 /opt/maven && \
  ln -s /opt/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME=/opt/maven

USER 1001
```

## Image Tags

Red Hat khuyến nghị sử dụng **specific version tags** thay vì `latest` trong production:

```yaml
# Thay vì:
image: registry.redhat.io/ocp-tools-4/jenkins-agent-base-rhel8:latest

# Nên dùng:
image: registry.redhat.io/ocp-tools-4/jenkins-agent-base-rhel8:v4.12
```

Kiểm tra available tags tại:
- https://catalog.redhat.com/software/containers/explore

## Tham khảo

- [Red Hat Jenkins Images Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.12/html/jenkins/images-other-jenkins-agent)
- [Red Hat Container Catalog](https://catalog.redhat.com)
- [Universal Base Images (UBI)](https://developers.redhat.com/products/rhel/ubi)
