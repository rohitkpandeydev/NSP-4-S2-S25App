# NSP-4-S2-S25App

Serverless backend deployed with Terraform, AWS Lambda, API Gateway, and GitHub OIDC.

## Features

- **Zero-Downtime Deployments:** Updates Lambda code in place without changing the API endpoint.
- **Ultra-Reliable LLM Integration:** 4-tier fallback system:
    1. **Hugging Face Router** (DeepSeek-V4-Flash)
    2. **Hugging Face Standard API** (via `hf.co` alias)
    3. **ZenQuotes API** (Public quotes)
    4. **Typefit API** (Secondary quote fallback)
- **Security & Quality Gates:**
    - **GitHub OIDC:** No long-lived AWS secrets in the repo.
    - **Checkov:** IaC security scanning.
    - **Super Linter:** Code quality for Go and Terraform.
    - **Terraform Plan:** Visible in PRs before merging.

## Deployment Setup

1. **Dependencies:** Ensure `infrastructure-bootstrap` has been run.
2. **GitHub Variables:**
    - `APP_DEPLOY_ROLE_ARN`: The IAM role ARN from the bootstrap repo.
    - `AWS_REGION`: e.g., `ap-south-2`.
    - `LAMBDA_KMS_KEY_ARN`: KMS key ARN for Lambda environment variable encryption (optional).
3. **GitHub Secrets:**
    - `HUGGINGFACE_API_TOKEN`: Your Hugging Face access token.

## Testing the API

```bash
curl -X POST "https://fux17srgoh.execute-api.ap-south-2.amazonaws.com/invoke" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Explain serverless deployment in one sentence."}'
```

Alternatively, use the provided helper script:

```bash
bash demo/test_api.sh
```

## Repository Structure

- `lambda/`: Go source code and unit tests.
- `terraform/`: Infrastructure as Code for Lambda and API Gateway.
- `demo/`: Shell script for manually testing the deployed API endpoint.
- `build/`: Compiled Lambda binary (`bootstrap`), generated during CI/CD — not committed to source control.
- `.github/workflows/`:
    - `pr-validation.yml`: Runs Linter, Checkov, and Terraform Plan.
    - `deploy.yml`: Builds and deploys the application to AWS.
