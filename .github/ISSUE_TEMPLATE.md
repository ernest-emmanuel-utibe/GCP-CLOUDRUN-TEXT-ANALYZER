---
name: Bug Report
about: Create a report to help us improve
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description
A clear and concise description of what the bug is.

## Environment
- **Project ID**: [your-gcp-project-id]
- **Region**: [e.g., us-central1]
- **Deployment Method**: [GitHub Actions / Manual / Cloud Build]
- **Python Version**: [e.g., 3.11]
- **Terraform Version**: [e.g., 1.5.0]

## Steps to Reproduce
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

## Expected Behavior
A clear and concise description of what you expected to happen.

## Actual Behavior
A clear and concise description of what actually happened.

## Error Messages
```
Paste any error messages here
```

## Logs
<details>
<summary>Cloud Run Logs</summary>

```
Paste Cloud Run logs here
```
</details>

<details>
<summary>Terraform Output</summary>

```
Paste terraform plan/apply output here
```
</details>

<details>
<summary>GitHub Actions Logs</summary>

```
Paste GitHub Actions workflow logs here
```
</details>

## Configuration Files
<details>
<summary>terraform.tfvars</summary>

```hcl
# Remove sensitive values
project_id = "your-project-id"
region = "us-central1"
environment = "dev"
```
</details>

## Additional Context
Add any other context about the problem here.

## Checklist
- [ ] I have searched existing issues to ensure this is not a duplicate
- [ ] I have provided all requested information
- [ ] I have removed sensitive information from logs and configurations
- [ ] I have tested this on a clean deployment

---

## For Feature Requests

### Feature Description
A clear and concise description of the feature you'd like to see.

### Use Case
Describe your use case and why this feature would be valuable.

### Proposed Solution
Describe the solution you'd like to see implemented.

### Alternative Solutions
Describe any alternative solutions or features you've considered.

### Additional Context
Add any other context, screenshots, or examples about the feature request.