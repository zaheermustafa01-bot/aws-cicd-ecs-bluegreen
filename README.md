# AWS CI/CD Pipeline — Zero-Downtime ECS Fargate Deployments

[![Terraform](https://img.shields.io/badge/Terraform-1.5%2B-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-CodePipeline%20%7C%20CodeBuild%20%7C%20CodeDeploy-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/)
[![ECS Fargate](https://img.shields.io/badge/Compute-ECS%20Fargate-FF9900?logo=amazonecs&logoColor=white)](https://aws.amazon.com/fargate/)
[![Python](https://img.shields.io/badge/App-Flask%20%2F%20Python%203.12-3776AB?logo=python&logoColor=white)](https://flask.palletsprojects.com/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A complete, production-shaped CI/CD pipeline that builds a Docker image,
pushes it to ECR, and deploys it to ECS Fargate using a **blue/green**
strategy — no downtime, automatic smoke testing, and automatic rollback
on failure.

> Built to demonstrate the kind of pipeline I'd actually run in a
> production AWS environment, not a toy example. Every resource is
> provisioned with Terraform, every deployment goes through health
> checks and traffic shifting, and rollback is automatic.

## The problem this solves

Rolling deployments on ECS replace tasks in place — there's no safe point
to validate a new version before it serves real traffic, and rolling back
means redeploying the old task definition. This pipeline instead runs the
new version ("green") alongside the current one ("blue"), smoke-tests it
on a separate ALB listener, then shifts traffic gradually — with
automatic rollback if anything fails.

See [`docs/architecture.md`](docs/architecture.md) for the full
diagram and design rationale.

## What's in this repo

| Path | What it is |
|---|---|
| `terraform/modules/vpc` | VPC, public/private subnets, NAT gateway, route tables |
| `terraform/modules/alb` | ALB with blue/green target groups, prod + test listeners |
| `terraform/modules/ecs` | ECS cluster, Fargate task definition, service (CodeDeploy-controlled) |
| `terraform/modules/codepipeline` | CodePipeline, CodeBuild project, CodeDeploy app/deployment group, ECR-triggered IAM roles |
| `terraform/environments/dev` | Dev environment root module — 2 AZs, linear 10%/1min rollout |
| `terraform/environments/prod` | Prod environment root module — 3 AZs, canary 10%/5min rollout |
| `app/` | Sample Flask service (health endpoint, version endpoint) + Dockerfile |
| `buildspecs/buildspec.yml` | CodeBuild spec: builds image, pushes to ECR, generates CodeDeploy artifacts |
| `buildspecs/smoke-test-buildspec.yml` | Template for a post-deploy smoke test against the green target group — **not auto-wired into the pipeline** (would need a CodeDeploy lifecycle-hook Lambda or an extra CodeBuild action to actually invoke it; included as the next concrete step, see "What I'd add" below) |
| `scripts/rollback.sh` | Manual rollback if auto-rollback doesn't trigger |
| `scripts/local-test.sh` | Build + run the app container locally before touching the pipeline |

## How it works

1. Push to the tracked branch → CloudWatch Events triggers the pipeline
   (event-driven, not polling)
2. **CodeBuild** builds the image, pushes to ECR, generates
   `taskdef.json` + `appspec.yaml`
3. **CodeDeploy** stands up a new ("green") ECS task set, attaches it to
   a separate target group, and routes a test listener (`:8443`) to it
4. The test listener (`:8443`) gives a window to smoke-test the green
   version before it's public — see the caveat on
   `smoke-test-buildspec.yml` above. Once ready, traffic shifts from
   blue to green per the deployment config (linear in dev, canary in
   prod)
5. CloudWatch alarms or failed health checks trigger automatic rollback
   to blue — no manual redeploy needed

## Why these design choices

- **Two environments as separate root modules, not Terraform
  workspaces** — so a mistake in dev state can never touch prod, and the
  two can genuinely diverge (different AZ count, different rollout
  speed).
- **ECR repo provisioned at the root level**, not inside the
  `codepipeline` module — avoids a circular dependency where ECS needs
  the image URI and CodePipeline needs the ECS service name.
- **Event-driven pipeline trigger** via CloudWatch Events instead of
  `PollForSourceChanges` — removes the ~1 minute polling lag and avoids
  CodeCommit API throttling on busy repos.
- **`CodeDeployDefault.ECSLinear10PercentEvery1Minute` in dev** for fast
  iteration feedback, **`CodeDeployDefault.ECSCanary10Percent5Minutes`
  in prod** to limit blast radius if a bad deploy slips through.

## Running it yourself

```bash
# 1. Test the app locally first
./scripts/local-test.sh

# 2. Deploy the dev environment
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars   # edit as needed
terraform init
terraform plan
terraform apply

# 3. Push code to the generated CodeCommit repo (URL is in the
#    `codecommit_clone_url_http` output) and watch the pipeline run
#    in the CodePipeline console.
```

Requires: Terraform >= 1.5, an AWS account with credentials configured,
Docker (for local testing).

## What I'd add for a real production rollout

- Wire `buildspecs/smoke-test-buildspec.yml` into the actual deployment
  flow via a CodeDeploy `AfterAllowTestTraffic` Lambda hook — currently
  it's a template, not invoked automatically
- ACM certificate + HTTPS listener (omitted here so the demo doesn't
  require a registered domain — see `docs/architecture.md`)
- WAF attached to the ALB
- Remote state backend (S3 + DynamoDB lock table — config is stubbed out
  in `main.tf`, commented because it needs a pre-existing bucket)
- CloudWatch alarms wired into the CodeDeploy deployment group's
  `alarm_configuration` block for automatic rollback on error-rate spikes,
  not just deployment failures

## Stack

Terraform · AWS CodePipeline · AWS CodeBuild · AWS CodeDeploy · ECS
Fargate · ECR · Application Load Balancer · CloudWatch · Python / Flask ·
Docker

---

Part of a 6-repo DevOps portfolio. Built by [Muhammad Zaheer Mustafa](https://www.linkedin.com/) — Senior DevOps Engineer, AWS Certified DevOps Engineer Professional.
