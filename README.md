# NSP-4-S2-S25App

Serverless backend deployed with Terraform, AWS Lambda, API Gateway HTTP API, GitHub Actions, OIDC, Checkov, Super Linter, and Go.

## What it deploys

- A Go Lambda function using the `provided.al2023` runtime.
- A stable API Gateway HTTP API endpoint at `POST /invoke`.
- CloudWatch log groups with retention.
- Lambda package hashing with `source_code_hash`, so code changes update the function in place without replacing the API Gateway endpoint.

## GitHub setup

Create these repository variables:

- `APP_DEPLOY_ROLE_ARN`: output from the bootstrap repository.
- `AWS_REGION`: optional, defaults to `ap-south-2`.

Optional repository secret:

- `HUGGINGFACE_API_TOKEN`: enables Hugging Face inference. Without it, the Lambda still calls a free public quote API and returns a simulated assistant response.

No static AWS access keys are required in this repository.

Terraform state is stored in `s3://bits-hw-nsp4-terraform-state/NSP-4-S2-S25App/terraform.tfstate` with native S3 lock files enabled.

The app deployment role created by the bootstrap repository includes the S3 permissions required for this state file and its `.tflock` file.

## Deployment order

1. Deploy `infrastructure-bootstrap`.
2. Copy its `application_deploy_role_arn` output.
3. Add that ARN as `APP_DEPLOY_ROLE_ARN` in this repository's Actions variables.
4. Push to `main` or run the `Deploy Application` workflow manually.
5. Use the printed `invoke_url`.

## Test the API

```bash
curl -X POST "$INVOKE_URL" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Explain serverless deployment in one sentence."}'
```

The API Gateway endpoint remains static across Lambda code updates because Terraform updates the Lambda package in place and does not recreate the HTTP API resource.
