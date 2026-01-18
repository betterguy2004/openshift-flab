---
description: Evidence-based research workflow - Always cite official documentation before answering
---

# Evidence-Based Research Workflow

This workflow ensures all technical answers are backed by official documentation citations.

## Mandatory Flow

### Step 1: Find Official Documentation
Before answering any technical question, search for and cite official documentation in this priority order:
1. **Vendor docs** (e.g., docs.redhat.com for OpenShift)
2. **Upstream docs** (e.g., kubernetes.io for Kubernetes)
3. **Official release notes**

### Step 2: Verify Citation Exists
- ✅ If official citation found → Proceed to Step 3
- ❌ If NO official citation found → Return only:
  ```
  Chưa đủ bằng chứng trong official docs
  
  Truy vấn cần chạy: [specific search queries]
  Trang official nên đọc: [specific official doc URLs]
  ```
  **DO NOT conclude without official evidence.**

### Step 3: Extract Evidence
Extract 1-3 short paragraphs or bullet points from official documentation that directly address the question.

### Step 4: Format Response

Every answer must follow this exact format:

```
## Official Evidence

**Evidence 1:**
[Trích dẫn ngắn từ official docs]
🔗 Source: [direct link to official doc]

**Evidence 2:**
[Trích dẫn ngắn từ official docs]
🔗 Source: [direct link to official doc]

**Evidence 3:** (if applicable)
[Trích dẫn ngắn từ official docs]
🔗 Source: [direct link to official doc]

## Kết Luận

[Your conclusion based strictly on the evidence above]
```

### Step 5: Community Sources (Optional)
Only use blog/community sources when:
- Official docs don't provide clear guidance, AND
- You label them explicitly as **"Non-official (for context)"**

Format for non-official sources:
```
## Non-official (for context)

[Community insight or blog reference]
🔗 Source: [community/blog link]
```

## Official Documentation Sources

### Kubernetes
- Primary: `kubernetes.io/docs/*`
- Release notes: `kubernetes.io/docs/setup/release/notes/`
- GitHub: `github.com/kubernetes/*`

### OpenShift(version 4.12)
- Primary: `docs.redhat.com/en/documentation/openshift_container_platform/4.12/`
- Access: `access.redhat.com/documentation/en-us/openshift_container_platform/`

### Helm
- Primary: `helm.sh/docs/`
- GitHub: `github.com/helm/*`
- Release notes: `github.com/helm/helm/releases`

## Example: Insufficient Evidence Response

```
## Tôi chưa tìm thấy trong official docs

Câu hỏi yêu cầu thông tin về [topic], nhưng tôi chưa tìm thấy bằng chứng rõ ràng trong tài liệu chính thức.

### Truy vấn cần chạy:
1. Search "site:kubernetes.io [specific keywords]"
2. Search "site:docs.redhat.com [specific keywords]"
3. Check release notes for version [X.Y]

### Trang official nên đọc:
- https://kubernetes.io/docs/concepts/[relevant-section]/
- https://docs.redhat.com/en/documentation/openshift_container_platform/4.12/html/[relevant-guide]/
```

## Important Rules

1. **Never conclude without official evidence** - If you can't find official docs, admit it
2. **Always include direct links** - Every evidence must have a source URL
3. **Keep evidence concise** - 1-3 short extracts, not full pages
4. **Prioritize correctly** - Vendor > Upstream > Release notes > Community
5. **Label non-official sources** - Always mark community/blog content clearly
6. **Version-aware** - Specify which version the documentation refers to
7. **Direct quotes or paraphrases** - Must accurately represent the official source

## Red Flags to Avoid

- ❌ Answering without citing sources
- ❌ Using community blogs as primary evidence
- ❌ Mixing official and non-official sources without clear labeling
- ❌ Citing outdated documentation versions
- ❌ Making assumptions when official docs are unclear