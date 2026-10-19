# Working with the GitHub repository

Repository: [Kareem-Saeed1/aws-03](https://github.com/Kareem-Saeed1/aws-03).

## Submit an update

```bash
git clone https://github.com/Kareem-Saeed1/aws-03.git
cd aws-03
git switch -c docs/update-runbook
# Edit the relevant files, then review the changes.
git diff
git add README.md docs/
git diff --cached
git commit -m "Update deployment runbook"
git push -u origin docs/update-runbook
```

Open a pull request to `main` and review the validation workflow before merging. Stage only the files intended for the change.

## Repository settings

Enable dependency alerts and private vulnerability reporting where available. For ongoing development, protect `main` with a ruleset that requires pull requests and successful validation.

Suggested description: Two-AZ AWS web application with Terraform, private EC2 Auto Scaling, ALB/WAF, CloudFront and RDS Multi-AZ.

Suggested topics: `aws`, `terraform`, `ec2`, `autoscaling`, `alb`, `cloudfront`, `rds`, `devops`.

## Before publishing evidence

Confirm that the README diagram renders and the editable source is available. Add only actual test results and sanitized screenshots under `docs/evidence/`.

Never commit `.terraform/`, `*.tfstate*`, `*.tfplan`, real `terraform.tfvars`, `backend.hcl`, `.env`, private keys, credentials or authorization headers. Provider lock files belong in source control.

Source: [GitHub documentation](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github).
