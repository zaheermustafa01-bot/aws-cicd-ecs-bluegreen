# Architecture

## Overview

This pipeline takes a code change and turns it into a live, zero-downtime
deployment on ECS Fargate using a blue/green strategy, with automatic
rollback if health checks fail.

```
Developer push
      |
      v
+------------------+      +-----------------+      +--------------------+
|  CodeCommit repo  | ---> |  CodePipeline    | ---> |  CodeBuild          |
|  (or GitHub via   |      |  Source stage    |      |  - docker build     |
|  CodeStar Conn.)  |      |                  |      |  - push to ECR      |
+------------------+      +-----------------+      |  - generate          |
                                                      |    taskdef.json /   |
                                                      |    appspec.yaml     |
                                                      +----------+----------+
                                                                 |
                                                                 v
                                                      +--------------------+
                                                      |  CodeDeploy          |
                                                      |  Blue/Green ECS      |
                                                      |  deployment          |
                                                      +----------+----------+
                                                                 |
                       +----------------------+------------------+
                       |                      |
                       v                      v
              +----------------+     +----------------+
              | ALB: Blue TG    |     | ALB: Green TG   |
              | (current live)  |     | (new version)    |
              +----------------+     +----------------+
                       \                      /
                        \                    /
                         v                  v
                    +-----------------------------+
                    |  Application Load Balancer    |
                    |  - prod listener :80          |
                    |  - test listener :8443         |
                    +-----------------------------+
                                  |
                                  v
                       +-----------------------+
                       | ECS Fargate tasks      |
                       | (private subnets)      |
                       +-----------------------+
```

## Deployment flow

1. A commit lands on the tracked branch. A CloudWatch Events rule fires
   on the CodeCommit `referenceUpdated` event and starts the pipeline
   (no polling, which avoids the ~1 minute polling delay and API throttling
   you get with `PollForSourceChanges`).
2. **CodeBuild** builds the Docker image, pushes it to ECR with both a
   commit-hash tag and `latest`, then generates `taskdef.json` and
   `appspec.yaml` — the two files CodeDeploy needs to know what to deploy
   and how to wire it into the load balancer.
3. **CodeDeploy** registers a new ECS task set ("green") alongside the
   running one ("blue"), attaches it to the green target group, and
   routes the test listener (port 8443) to it so the pipeline can run
   smoke tests against the new version without it being public yet.
4. Traffic is shifted from blue to green according to the deployment
   config — `CodeDeployDefault.ECSLinear10PercentEvery1Minute` in dev
   (fast feedback) or `CodeDeployDefault.ECSCanary10Percent5Minutes` in
   prod (slower, safer rollout: 10% of traffic for 5 minutes, then the
   rest).
5. If CloudWatch alarms fire or the deployment fails, CodeDeploy
   automatically rolls back to blue. The old task set is terminated only
   after a successful deployment, with a 5-minute grace period
   (`terminate_blue_instances_on_deployment_success`).

## Why blue/green over rolling deployments

A standard ECS rolling deployment replaces tasks in place — there's no
clean point to test the new version before it's serving real traffic, and
rollback means redeploying the old task definition (slow). Blue/green
keeps both versions running simultaneously behind separate target groups,
so:

- The new version can be smoke-tested on a separate listener before going
  live
- Rollback is just flipping the listener back to the blue target group —
  seconds, not a redeploy
- You get an explicit "two full environments" model, which matches how
  CodeDeploy's traffic-shifting and alarm-based rollback are designed to
  work

## Network design

- **Public subnets**: only the ALB lives here, across 2 (dev) or 3 (prod)
  AZs.
- **Private subnets**: ECS tasks run here with no public IP. Outbound
  internet access (for pulling images from ECR, hitting AWS APIs) goes
  through a NAT Gateway.
- **Security groups**: the ECS task security group only accepts inbound
  traffic from the ALB security group, on port 8080 — nothing else can
  reach the tasks directly.

## Why two Terraform environments instead of workspaces

`environments/dev` and `environments/prod` are separate root modules
rather than Terraform workspaces sharing one state file. This means a
mistake in dev (wrong CIDR, bad IAM policy, accidental `terraform destroy`)
can't touch prod state, and the two environments can genuinely diverge —
prod runs 3 AZs and a canary deployment config, dev runs 2 AZs and a
faster linear rollout. Workspaces are convenient but make this kind of
deliberate divergence awkward.

## Why the image URI is written directly, not via CodeDeploy's `<IMAGE1_NAME>` substitution

CodePipeline's CodeDeploy-to-ECS action supports a placeholder mechanism
(`<IMAGE1_NAME>` in `taskdef.json`, resolved from an `imageDetail.json`
artifact) for injecting the built image's URI. This pipeline skips it:
CodeBuild already knows the exact image URI and tag it just pushed, so
`buildspecs/buildspec.yml` writes the real value straight into
`taskdef.json`. One less moving part, one less artifact to wire up, and
no risk of the substitution silently failing (a documented pain point —
several public write-ups report the placeholder mechanism not resolving
reliably for ECS deploys). The `<TASK_DEFINITION>` placeholder in
`appspec.yaml` is kept, since that one is templated reliably by
CodeDeploy itself, not by CodePipeline's image-artifact mechanism.

## Why IAM role ARNs and log group name are CodeBuild env vars, not placeholders

Only the container image and the task definition ARN get dynamic
substitution from CodeDeploy/CodePipeline. Execution role, task role,
CPU/memory, and the log group name don't — so the buildspec receives
them as CodeBuild environment variables (set on the `aws_codebuild_project`
resource, sourced from the ECS module's outputs) and bakes them into
`taskdef.json` directly.



- **HTTPS/ACM certificate**: omitted to keep the demo deployable without
  requiring a registered domain. In a real environment, add an
  `aws_acm_certificate` and an HTTPS listener on 443, and redirect 80→443.
- **WAF**: not wired in, but the ALB module is the natural attachment
  point (`aws_wafv2_web_acl_association`) if you need it.
- **Multi-region**: this is a single-region pipeline. A genuinely
  multi-region setup would need Route 53 health-check-based failover and
  either cross-region ECR replication or per-region pipelines.
