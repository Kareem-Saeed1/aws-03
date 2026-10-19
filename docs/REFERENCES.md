# Primary references

Reviewed during package preparation on 19 October 2026. Service availability, provider schemas and prices can change; re-check the selected Region before deployment.

| Topic | Official source | Applied in this project |
|---|---|---|
| Repository organization | [AWS Solutions example](https://github.com/aws-solutions/dynamic-image-transformation-for-amazon-cloudfront/) | Overview, diagram, prerequisites and deployment documentation |
| VPC with private servers | [AWS two-AZ VPC example](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-example-private-subnets-nat.html) | Public ALB, private compute, NAT in both AZs |
| Zonal NAT resilience | [NAT gateway basics](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-basics.html) | Same-AZ outbound routing |
| RDS Multi-AZ instance | [RDS single standby](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZSingleStandby.html) | Standby used for failover, not read scaling |
| Database failover | [RDS failover](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.Failover.html) | Live recovery exercise |
| PostgreSQL TLS | [RDS SSL connections](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html) | Encrypted connection with CA verification |
| CloudFront private S3 | [Origin Access Control](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html) | Signed access to private static bucket |
| Certificates | [CloudFront certificate requirements](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html) | Viewer certificate in us-east-1 |
| DNS health | [Route 53 AliasTarget](https://docs.aws.amazon.com/Route53/latest/APIReference/API_AliasTarget.html) | ALB alias health evaluation |
| Scaling | [Target tracking](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-target-tracking.html) | CPU target tracking |
| Scaling exercise | [Step scaling](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-simple-step.html) | Separate step policy mode |
| Deployment updates | [Instance refresh](https://docs.aws.amazon.com/autoscaling/ec2/userguide/asg-instance-refresh.html) | Rolling instance replacement |
| Session Manager | [Prerequisites](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-prerequisites.html) | Agent, role and endpoint connectivity |
| WAF baseline | [Managed rule groups](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-baseline.html) | Common attack protections |
| WAF rollout | [Testing and tuning](https://docs.aws.amazon.com/waf/latest/developerguide/web-acl-testing.html) | False-positive review |
| Terraform state | [S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3) | Versioned encrypted state and lockfile |
| Sensitive state | [Terraform sensitive data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data) | Protect state and plan artifacts |
| Pricing | [AWS Pricing Calculator](https://calculator.aws/) | Region-specific cost estimate before apply |
| GitHub upload | [Add local code to GitHub](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github) | Publish the extracted repository contents |

The code and diagrams are original project artifacts. Citations support AWS/HashiCorp behavior; they do not imply that AWS reviewed or endorsed this repository.
