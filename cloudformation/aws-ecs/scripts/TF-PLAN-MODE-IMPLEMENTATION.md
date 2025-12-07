# Terraform Plan JSON Mode - Implementation Plan

## Status: ✅ IMPLEMENTED

Completed on 2025-12-07.

## Goal
Enhance `tf-cfn-sync.py` to consume `terraform plan -json` output for more accurate resource matching and property comparison.

## Implementation Summary

### What Was Done

1. **Added `enable_route53_dns` variable** to make DNS/ACM resources conditional
   - Modified: `terraform/aws-ecs/variables.tf`
   - Modified: `terraform/aws-ecs/keycloak-dns.tf`
   - Modified: `terraform/aws-ecs/registry-dns.tf`
   - Modified: `terraform/aws-ecs/keycloak-alb.tf`
   - Modified: `terraform/aws-ecs/main.tf`
   - Modified: `terraform/aws-ecs/outputs.tf`

2. **Added `--tf-plan` flag** to `tf-cfn-sync.py`
   - New function: `parse_tf_plan_json()` parses the JSON structure
   - Extracts resources from `planned_values.root_module` recursively
   - Handles nested child modules

3. **Added missing type mappings**:
   - `aws_efs_backup_policy` → `AWS::EFS::FileSystem`
   - `aws_efs_file_system_policy` → `AWS::EFS::FileSystem`
   - `aws_route_table_association` → `AWS::EC2::SubnetRouteTableAssociation`
   - `aws_default_*` → `SKIP` (VPC defaults not managed in CFN)

### Results Comparison

| Mode | TF Resources | Matched | TF Only | CFN Only |
|------|--------------|---------|---------|----------|
| HCL parsing | 85 | 32 | 53 | 131 |
| Plan JSON | 263 | 51 | 212 | 112 |

The plan JSON mode finds significantly more resources because it expands all modules.

## Usage

### Generate Plan JSON (with DNS disabled)

```bash
cd terraform/aws-ecs
terraform init
terraform plan \
  -var='enable_route53_dns=false' \
  -var='keycloak_admin_password=dummy' \
  -var='keycloak_database_password=dummy' \
  -out=plan.tfplan
terraform show -json plan.tfplan > ../../cloudformation/aws-ecs/tf-plan.json
```

### Run Sync Tool with Plan JSON

```bash
cd cloudformation/aws-ecs
uv run python scripts/tf-cfn-sync.py --tf-plan cloudformation/aws-ecs/tf-plan.json --output sync-tasks-plan/
```

### Run Sync Tool with HCL Parsing (fallback)

```bash
cd cloudformation/aws-ecs
uv run python scripts/tf-cfn-sync.py --output sync-tasks/
```

Note: The `--tf-plan` path is relative to the repo root, not the current directory.

## Workaround: Conditional DNS

The `enable_route53_dns` variable was added because:
- Terraform plan requires Route53 hosted zones to exist for data source lookups
- Without real `mycorp.click` zones, plan fails with "no matching Route 53 Hosted Zone found"
- Setting `enable_route53_dns=false` skips all DNS/ACM resources

This allows generating plan JSON for code comparison without:
- Deploying infrastructure
- Having Route53 hosted zones configured
- Real AWS credentials (though init still needs them)

## Files Modified

- `terraform/aws-ecs/variables.tf` - Added `enable_route53_dns` variable
- `terraform/aws-ecs/keycloak-dns.tf` - Made all resources conditional
- `terraform/aws-ecs/registry-dns.tf` - Made all resources conditional
- `terraform/aws-ecs/keycloak-alb.tf` - Made HTTPS listener conditional, added HTTP fallback
- `terraform/aws-ecs/main.tf` - Made certificate_arn conditional
- `terraform/aws-ecs/outputs.tf` - Made DNS outputs conditional
- `cloudformation/aws-ecs/scripts/tf-cfn-sync.py` - Added `--tf-plan` flag and JSON parser

See `terraform/aws-ecs/CONDITIONAL-DNS-CHANGES.md` for detailed explanation of the Terraform changes (for TF team review).

## Future Enhancements

1. **Property-level comparison** - Compare resolved TF values against CFN properties
2. **Drift detection** - Flag resources where TF and CFN values differ
3. **Auto-generate CFN snippets** - Use resolved values from plan JSON
