# Acceptance tests and evidence

All AWS tests below are **pending** until you run them. Perform destructive/recovery exercises only in this lab. Record actual UTC timestamps, observations, interruptions and limits. Do not fabricate AWS console screenshots or mark an unexecuted test as passed.

## Local validation

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r app/requirements.txt -r tests/requirements.txt
pytest -q tests
terraform -chdir=infra init -backend=false
terraform -chdir=infra validate
terraform -chdir=infra fmt -check -recursive
```

Use a clean copy for backend-disabled CI validation. For an already-deployed working directory, preserve its configured backend. Unit tests use database mocks; they do not prove PostgreSQL grants, AWS IAM or live infrastructure behavior.

## Live acceptance matrix

| ID | Exercise | Pass criteria | Evidence |
|---|---|---|---|
| T01 | Network inspection | Two AZs, six subnets, correct routes, no EC2 public IP, RDS private | Subnet/route and instance views |
| T02 | HTTPS and routing | HTTP redirects; app host serves app; unknown ALB host returns 404 | HTTP headers and listener rules |
| T03 | Application persistence | Login, create task, refresh and observe same task | Sanitized application screenshot |
| T04 | Health | Two targets healthy; `/ready` returns 200 after DB initialization | Target health and response |
| T05 | Instance replacement | Application usable during one instance termination; ASG creates replacement; task survives | ASG activities, timestamps, responses |
| T06 | Target tracking | Controlled CPU load raises average metric and desired capacity; later scales in to min 2 | CPU graph, scaling history |
| T07 | Step scaling | Switch policy mode, demonstrate step-out and step-in, restore target tracking | Policy/alarm/activity views |
| T08 | Static caching | CSS retrieved through CloudFront; repeat request obtains cache hit/Age | Response headers |
| T09 | Private S3 | Direct unsigned S3 object GET denied; CloudFront GET succeeds | HTTP status observations |
| T10 | WAF | Harmless test header blocked with 403; normal request works | WAF rule log + response |
| T11 | SSM | Session opens to private instance; no inbound SSH | Session and SG evidence |
| T12 | RDS failover | Controlled forced failover; app reconnects; prior record remains | RDS events, outage timing |
| T13 | Alerts | SNS subscription confirmed; alarm notification delivered | Redacted notification |
| T14 | Bootstrap revocation | Bootstrap output false; admin secret denied to EC2; app still works | Sanitized denial and app result |
| T15 | Backup restore | Restore snapshot to isolated DB; validate test data | Restore notes; optional extended exercise |

T05 is an instance-failure exercise, not a simulation of total AZ loss. T12 does not promise zero interruption or a fixed failover time.

## Smoke test

```bash
python scripts/smoke-test.py \
  --app-url "$(terraform -chdir=infra output -raw application_url)" \
  --static-url "$(terraform -chdir=infra output -raw static_css_url)"
```

It prompts privately for credentials and checks health, readiness, authentication, WAF test blocking and CSS delivery. It does not write database records or induce failures.

## Instance replacement

Create a task, then record healthy target count. Through EC2, terminate exactly one ASG-managed instance. Observe ASG activities and request responses while the other instance serves traffic. Wait for replacement to pass health checks. Verify the original task remains. Save before/after evidence and the measured impact; do not terminate both instances together.

## Scaling exercises

Use Session Manager to run the contents of `scripts/cpu-load.sh` on **both** existing application instances. The script creates a bounded seven-minute CPU load and stops automatically. Do not run it on your laptop or on shared/production instances. ASG average CPU may not reach its target if only one instance is stressed. New instances dilute the average, which is expected. A controlled CPU exercise proves scaling mechanics, not real workload throughput or latency capacity.

Observe the ASG desired capacity and scaling activity. After the load stops, wait for warmup, cooldown behavior and alarm evaluation. Burstable instances can consume CPU credits and incur additional charges depending on credit mode.

For step scaling, set `enable_step_scaling = true` in tfvars and apply. This removes target tracking and enables CPU >60% for two one-minute periods to scale out (+1 below 80%, +2 at/above 80%). CPU <20% for ten one-minute periods scales in by one, subject to min 2. Repeat the controlled load. Restore `enable_step_scaling = false` and apply when finished.

## Database failover

Record a task and start checking the application periodically. In RDS, select the lab DB and choose Reboot with failover, or run this only after confirming the identifier:

```bash
aws rds reboot-db-instance \
  --db-instance-identifier "$(terraform -chdir=infra output -raw db_identifier)" \
  --force-failover
```

Record the start/end timestamps, 503/error interval, RDS events and post-recovery task data. The app opens new DB connections on each request; retry a failed page after recovery. Do not blindly retry a write whose commit status is uncertain.

## Alarm delivery

After confirming the SNS email, use the unhealthy-target incident during an approved test to observe a real alarm transition. Alternatively, use CloudWatch's SetAlarmState for a clearly labeled synthetic alarm-notification test and wait for the metric to restore the true state. A synthetic state change proves delivery, not the alarm threshold's detection behavior.

## Evidence handling

Use [evidence/results-template.md](evidence/results-template.md). Include timestamps and the actual Region, but remove passwords, Authorization headers, tokens, secret values, account IDs where unnecessary, and personal notification details. A screenshot of a configured resource is not proof of its behavior; include observations from the test.

Sources: [EC2 target tracking](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-target-tracking.html), [step scaling](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-simple-step.html), [RDS failover](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.Failover.html).
