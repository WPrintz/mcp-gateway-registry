# CloudFormation Sync Scripts

Tools for keeping CloudFormation templates in sync with Terraform.

## tf-cfn-sync.py

Generates focused, per-resource task files for syncing Terraform to CloudFormation.

### Quick Start

```bash
cd cloudformation/aws-ecs

# Run with mappings file (recommended)
uv run python scripts/tf-cfn-sync.py --tf-plan tf-plan.json

# Output goes to sync-tasks/
```

### Modes

#### Plan JSON Mode (Recommended)

Uses `terraform show -json` output for accurate module expansion:

```bash
# Generate plan JSON first (see TF-PLAN-MODE-IMPLEMENTATION.md)
cd terraform/aws-ecs
terraform plan -var='enable_route53_dns=false' \
  -var='keycloak_admin_password=dummy' \
  -var='keycloak_database_password=dummy' \
  -out=plan.tfplan
terraform show -json plan.tfplan > ../../cloudformation/aws-ecs/tf-plan.json

# Run sync tool
cd cloudformation/aws-ecs
uv run python scripts/tf-cfn-sync.py --tf-plan tf-plan.json
```

#### HCL Parsing Mode (Fallback)

Parses `.tf` files directly without Terraform installed:

```bash
uv run python scripts/tf-cfn-sync.py
```

### Manual Mappings File

The tool uses `tf-cfn-mappings.yaml` to reduce false positives by:
- Mapping TF module addresses to CFN logical IDs
- Skipping intentionally different resources
- Tracking known gaps

**AI Assistant Instructions**: When you see unmatched resources:
1. Check if they exist in CFN with different names → add to `mappings:`
2. If intentionally TF-only → add to `skip_tf_patterns:`
3. If real gap → add to `known_gaps:` and consider adding to CFN

### Output

```
sync-tasks/
├── summary.md          # Overview with AI instructions
└── tasks/              # One file per resource
    ├── 001-add-*.md    # Resources to add to CFN
    └── 002-update-*.md # Resources to review for drift
```

### Results

With mappings file:
| Category | Count |
|----------|-------|
| Matched | 91 |
| TF Only (real gaps) | 7 |
| CFN Only | 72 |
| Skipped | 165 |

The 7 TF-only resources are CloudWatch Alarms - the only real gap.

## Maintaining the Mappings File

### When to Update

Update `tf-cfn-mappings.yaml` when:
- Adding new resources to Terraform
- Adding new resources to CloudFormation
- Sync tool reports false positives

### Pattern Syntax

```yaml
mappings:
  # Exact match
  "aws_ecs_service.keycloak": "KeycloakService"
  
  # Wildcard for indices
  "module.vpc.aws_subnet.public*0*": "PublicSubnet1"
  
  # Wildcard for module paths
  "module.mcp_gateway.module.ecs_service_*.aws_ecs_service.this*": "AuthServerService"

skip_tf_patterns:
  # Skip all resources matching pattern
  - "random_*"
  - "module.mcp_gateway.module.ecs_service_*.aws_iam_role.*"

known_gaps:
  # Document real gaps for tracking
  - pattern: "module.mcp_gateway.aws_cloudwatch_metric_alarm.*"
    description: "Monitoring alarms"
    recommendation: "Add to services-stack.yaml"
    priority: "medium"
```

## Related Files

- `tf-cfn-mappings.yaml` - Manual TF↔CFN mappings
- `tf-plan.json` - Terraform plan output (generated)
- `TF-PLAN-MODE-IMPLEMENTATION.md` - How to generate plan JSON
- `TF-CFN-GAP-ANALYSIS.md` - Analysis of gaps between TF and CFN
