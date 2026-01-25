#!/usr/bin/env python3
"""
TF-CFN Sync Tool

Generates focused, per-resource task files for syncing Terraform to CloudFormation.
Each task file contains only the context needed for an agent to make the update.

Usage:
    # HCL parsing mode (default)
    uv run python scripts/tf-cfn-sync.py --output sync-tasks/
    
    # Plan JSON mode (more accurate, requires terraform plan output)
    uv run python scripts/tf-cfn-sync.py --tf-plan tf-plan.json --output sync-tasks/
    
    # With manual mappings file (reduces false positives)
    uv run python scripts/tf-cfn-sync.py --tf-plan tf-plan.json --mappings tf-cfn-mappings.yaml

AI ASSISTANT INSTRUCTIONS:
--------------------------
When running this tool and seeing unmatched resources:
1. Check if the resource exists in CFN with a different name
2. If yes, add a mapping to tf-cfn-mappings.yaml
3. If the resource is intentionally TF-only, add to skip_tf_patterns
4. If the resource is a real gap, add to known_gaps section
5. Re-run the tool to verify the mapping works
"""

import argparse
import fnmatch
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import hcl2
import yaml


# TF type -> CFN type mapping
TF_TO_CFN = {
    "aws_vpc": "AWS::EC2::VPC",
    "aws_subnet": "AWS::EC2::Subnet",
    "aws_internet_gateway": "AWS::EC2::InternetGateway",
    "aws_nat_gateway": "AWS::EC2::NatGateway",
    "aws_eip": "AWS::EC2::EIP",
    "aws_route_table": "AWS::EC2::RouteTable",
    "aws_route": "AWS::EC2::Route",
    "aws_security_group": "AWS::EC2::SecurityGroup",
    "aws_vpc_endpoint": "AWS::EC2::VPCEndpoint",
    "aws_ecs_cluster": "AWS::ECS::Cluster",
    "aws_ecs_service": "AWS::ECS::Service",
    "aws_ecs_task_definition": "AWS::ECS::TaskDefinition",
    "aws_lb": "AWS::ElasticLoadBalancingV2::LoadBalancer",
    "aws_lb_target_group": "AWS::ElasticLoadBalancingV2::TargetGroup",
    "aws_lb_listener": "AWS::ElasticLoadBalancingV2::Listener",
    "aws_rds_cluster": "AWS::RDS::DBCluster",
    "aws_rds_cluster_instance": "AWS::RDS::DBInstance",
    "aws_db_subnet_group": "AWS::RDS::DBSubnetGroup",
    "aws_db_proxy": "AWS::RDS::DBProxy",
    "aws_efs_file_system": "AWS::EFS::FileSystem",
    "aws_efs_mount_target": "AWS::EFS::MountTarget",
    "aws_efs_access_point": "AWS::EFS::AccessPoint",
    "aws_iam_role": "AWS::IAM::Role",
    "aws_secretsmanager_secret": "AWS::SecretsManager::Secret",
    "aws_ssm_parameter": "AWS::SSM::Parameter",
    "aws_kms_key": "AWS::KMS::Key",
    "aws_cloudwatch_log_group": "AWS::Logs::LogGroup",
    "aws_ecr_repository": "AWS::ECR::Repository",
    "aws_acm_certificate": "AWS::CertificateManager::Certificate",
    "aws_route53_record": "AWS::Route53::RecordSet",
    "aws_cloudfront_distribution": "AWS::CloudFront::Distribution",
    "aws_service_discovery_private_dns_namespace": "AWS::ServiceDiscovery::PrivateDnsNamespace",
    "aws_appautoscaling_target": "AWS::ApplicationAutoScaling::ScalableTarget",
    "aws_appautoscaling_policy": "AWS::ApplicationAutoScaling::ScalingPolicy",
    "aws_kms_alias": "AWS::KMS::Alias",
    "aws_db_proxy_target": "AWS::RDS::DBProxyTargetGroup",
    "aws_rds_cluster_parameter_group": "AWS::RDS::DBClusterParameterGroup",
    "aws_iam_role_policy": "AWS::IAM::Policy",
    "aws_iam_role_policy_attachment": "AWS::IAM::ManagedPolicy",
    "aws_iam_policy": "AWS::IAM::ManagedPolicy",
    "aws_secretsmanager_secret_version": "AWS::SecretsManager::Secret",
    "aws_ecs_cluster_capacity_providers": "AWS::ECS::ClusterCapacityProviderAssociations",
    "aws_ecr_lifecycle_policy": "AWS::ECR::Repository",
    "aws_ecr_repository_policy": "AWS::ECR::Repository",
    "aws_security_group_rule": "AWS::EC2::SecurityGroupIngress",
    "aws_vpc_security_group_ingress_rule": "AWS::EC2::SecurityGroupIngress",
    "aws_vpc_security_group_egress_rule": "AWS::EC2::SecurityGroupEgress",
    "aws_cloudwatch_metric_alarm": "AWS::CloudWatch::Alarm",
    "aws_acm_certificate_validation": "SKIP",  # Not needed in CFN
    "random_string": "SKIP",  # TF-only, use CFN !Sub or Secrets Manager
    "random_password": "SKIP",  # TF-only, use Secrets Manager GenerateSecretString
    "aws_efs_backup_policy": "AWS::EFS::FileSystem",  # Part of FileSystem in CFN
    "aws_efs_file_system_policy": "AWS::EFS::FileSystem",  # Part of FileSystem in CFN
    "aws_default_network_acl": "SKIP",  # VPC default, not typically managed in CFN
    "aws_default_route_table": "SKIP",  # VPC default, not typically managed in CFN
    "aws_default_security_group": "SKIP",  # VPC default, not typically managed in CFN
    "aws_route_table_association": "AWS::EC2::SubnetRouteTableAssociation",
}


@dataclass
class TFResource:
    """Parsed Terraform resource"""
    type: str
    name: str
    file: str
    line: int
    properties: dict
    module: str = ""
    raw_block: str = ""
    
    @property
    def address(self) -> str:
        if self.module:
            return f"module.{self.module}.{self.type}.{self.name}"
        return f"{self.type}.{self.name}"
    
    @property
    def cfn_type(self) -> str:
        return TF_TO_CFN.get(self.type, f"UNKNOWN:{self.type}")
    
    @property
    def suggested_cfn_id(self) -> str:
        """Generate a suggested CFN logical ID"""
        parts = self.name.replace("-", "_").split("_")
        return "".join(p.capitalize() for p in parts)


@dataclass
class CFNResource:
    """Parsed CloudFormation resource"""
    logical_id: str
    type: str
    file: str
    properties: dict
    raw_block: str = ""


@dataclass
class MappingConfig:
    """Manual TF-CFN mappings configuration"""
    mappings: dict[str, str] = field(default_factory=dict)  # TF pattern -> CFN logical ID
    skip_tf_patterns: list[str] = field(default_factory=list)
    skip_cfn_patterns: list[str] = field(default_factory=list)
    known_gaps: list[dict] = field(default_factory=list)


def load_mappings(mappings_path: Path) -> MappingConfig:
    """Load manual TF-CFN mappings from YAML file.
    
    AI ASSISTANT: If you need to reduce false positives, edit tf-cfn-mappings.yaml:
    - Add explicit mappings for TF resources that exist in CFN with different names
    - Add skip patterns for TF-only or CFN-only resources
    - Add known_gaps for resources that should be added to CFN
    """
    if not mappings_path.exists():
        print(f"  No mappings file found at {mappings_path}", file=sys.stderr)
        return MappingConfig()
    
    with open(mappings_path) as f:
        data = yaml.safe_load(f) or {}
    
    config = MappingConfig(
        mappings=data.get("mappings", {}),
        skip_tf_patterns=data.get("skip_tf_patterns", []),
        skip_cfn_patterns=data.get("skip_cfn_patterns", []),
        known_gaps=data.get("known_gaps", []),
    )
    
    print(f"  Loaded {len(config.mappings)} mappings, {len(config.skip_tf_patterns)} skip patterns", file=sys.stderr)
    return config


def matches_pattern(address: str, pattern: str) -> bool:
    """Check if a TF address matches a pattern (supports * wildcards)"""
    # Convert pattern to regex
    regex = pattern.replace(".", r"\.").replace("*", ".*")
    return bool(re.match(f"^{regex}$", address))


def should_skip_tf(tf_address: str, config: MappingConfig) -> bool:
    """Check if a TF resource should be skipped based on patterns"""
    for pattern in config.skip_tf_patterns:
        if matches_pattern(tf_address, pattern):
            return True
    return False


def find_mapping(tf_address: str, config: MappingConfig) -> str | None:
    """Find explicit CFN mapping for a TF address"""
    # Try exact match first
    if tf_address in config.mappings:
        return config.mappings[tf_address]
    
    # Try pattern matching
    for pattern, cfn_id in config.mappings.items():
        if "*" in pattern and matches_pattern(tf_address, pattern):
            return cfn_id
    
    return None


def parse_tf_plan_json(plan_path: Path) -> list[TFResource]:
    """Parse terraform plan JSON for fully-expanded resources.
    
    This mode provides more accurate resource matching because:
    - Module resources are fully expanded with resolved addresses
    - Variables and locals are resolved to actual values
    - Conditional resources (count/for_each) are expanded
    
    Generate the plan JSON with:
        terraform plan -out=plan.tfplan
        terraform show -json plan.tfplan > tf-plan.json
    """
    with open(plan_path) as f:
        plan = json.load(f)
    
    resources = []
    
    def extract_resources(module: dict, module_path: str = ""):
        """Recursively extract resources from module and child modules"""
        for res in module.get("resources", []):
            # Skip data sources
            if res.get("mode") == "data":
                continue
            
            # Build module path for nested modules
            address = res.get("address", "")
            
            resources.append(TFResource(
                type=res["type"],
                name=res["name"],
                file=f"plan:{address}",  # Mark as from plan
                line=0,
                properties=res.get("values", {}),
                module=module_path,
                raw_block=json.dumps(res.get("values", {}), indent=2, default=str)
            ))
        
        # Recurse into child modules
        for child in module.get("child_modules", []):
            child_addr = child.get("address", "")
            # Extract module name from address like "module.mcp_gateway.module.ecs_service"
            child_path = child_addr.replace("module.", "").replace(".", "/")
            extract_resources(child, child_path)
    
    root = plan.get("planned_values", {}).get("root_module", {})
    extract_resources(root)
    
    print(f"  Parsed {len(resources)} resources from plan JSON", file=sys.stderr)
    return resources


def parse_tf_files(tf_dir: Path) -> list[TFResource]:
    """Parse all Terraform files and extract resources"""
    resources = []
    
    for tf_file in tf_dir.rglob("*.tf"):
        # Skip .terraform directory
        if ".terraform" in str(tf_file):
            continue
            
        content = tf_file.read_text()
        rel_path = tf_file.relative_to(tf_dir)
        
        # Determine module path
        module = ""
        if "modules/" in str(rel_path):
            parts = str(rel_path).split("/")
            if len(parts) >= 2:
                module = parts[1]  # e.g., "mcp-gateway"
        
        try:
            parsed = hcl2.loads(content)
        except Exception as e:
            print(f"Warning: Could not parse {tf_file}: {e}", file=sys.stderr)
            continue
        
        # Extract resources
        for resource_block in parsed.get("resource", []):
            for res_type, res_instances in resource_block.items():
                for res_name, res_props in res_instances.items():
                    # Find line number (approximate)
                    line = find_line_number(content, res_type, res_name)
                    
                    # Extract raw block for context
                    raw = extract_raw_block(content, res_type, res_name)
                    
                    resources.append(TFResource(
                        type=res_type,
                        name=res_name,
                        file=str(rel_path),
                        line=line,
                        properties=res_props if isinstance(res_props, dict) else {},
                        module=module,
                        raw_block=raw
                    ))
    
    return resources


def find_line_number(content: str, res_type: str, res_name: str) -> int:
    """Find approximate line number of a resource definition"""
    pattern = rf'resource\s+"{res_type}"\s+"{res_name}"'
    for i, line in enumerate(content.split("\n"), 1):
        if re.search(pattern, line):
            return i
    return 0


def extract_raw_block(content: str, res_type: str, res_name: str) -> str:
    """Extract the raw HCL block for a resource"""
    pattern = rf'resource\s+"{res_type}"\s+"{res_name}"\s*\{{'
    match = re.search(pattern, content)
    if not match:
        return ""
    
    start = match.start()
    brace_count = 0
    end = match.end()
    
    for i, char in enumerate(content[match.end():], match.end()):
        if char == "{":
            brace_count += 1
        elif char == "}":
            if brace_count == 0:
                end = i + 1
                break
            brace_count -= 1
    
    return content[start:end]


def parse_cfn_files(cfn_dir: Path) -> list[CFNResource]:
    """Parse CloudFormation YAML files"""
    resources = []
    templates_dir = cfn_dir / "templates"
    
    if not templates_dir.exists():
        return resources
    
    # Custom YAML loader for CFN intrinsic functions
    class CFNLoader(yaml.SafeLoader):
        pass
    
    def cfn_constructor(loader, tag_suffix, node):
        if isinstance(node, yaml.ScalarNode):
            return {f"!{tag_suffix}": loader.construct_scalar(node)}
        elif isinstance(node, yaml.SequenceNode):
            return {f"!{tag_suffix}": loader.construct_sequence(node)}
        elif isinstance(node, yaml.MappingNode):
            return {f"!{tag_suffix}": loader.construct_mapping(node)}
    
    for tag in ['Ref', 'Sub', 'GetAtt', 'Join', 'Select', 'If', 'Equals', 
                'And', 'Or', 'Not', 'Condition', 'FindInMap', 'Base64', 'GetAZs',
                'ImportValue', 'Transform', 'Cidr', 'Split']:
        CFNLoader.add_multi_constructor(f'!{tag}', cfn_constructor)
    
    for yaml_file in templates_dir.glob("*.yaml"):
        if "single-stack" in yaml_file.name:
            continue
            
        content = yaml_file.read_text()
        rel_path = yaml_file.relative_to(cfn_dir)
        
        try:
            template = yaml.load(content, Loader=CFNLoader)
        except Exception as e:
            print(f"Warning: Could not parse {yaml_file}: {e}", file=sys.stderr)
            continue
        
        if not template or "Resources" not in template:
            continue
        
        for logical_id, res_def in template.get("Resources", {}).items():
            if not isinstance(res_def, dict):
                continue
            
            # Extract raw YAML block
            raw = extract_cfn_block(content, logical_id)
            
            resources.append(CFNResource(
                logical_id=logical_id,
                type=res_def.get("Type", "UNKNOWN"),
                file=str(rel_path),
                properties=res_def.get("Properties", {}),
                raw_block=raw
            ))
    
    return resources


def extract_cfn_block(content: str, logical_id: str) -> str:
    """Extract raw YAML block for a CFN resource"""
    lines = content.split("\n")
    start_idx = None
    end_idx = None
    base_indent = None
    
    for i, line in enumerate(lines):
        if re.match(rf"^  {logical_id}:", line):
            start_idx = i
            base_indent = 2
            continue
        
        if start_idx is not None and base_indent is not None:
            # Check if we've hit another resource at same indent
            if line.strip() and not line.startswith(" " * (base_indent + 1)):
                if re.match(r"^  [A-Z]", line):
                    end_idx = i
                    break
    
    if start_idx is not None:
        end_idx = end_idx or len(lines)
        return "\n".join(lines[start_idx:end_idx])
    
    return ""


def match_resources(tf_resources: list[TFResource], cfn_resources: list[CFNResource], 
                    config: MappingConfig = None) -> dict:
    """Match TF resources to CFN resources.
    
    Uses three-phase matching:
    1. Skip TF resources that match skip_tf_patterns
    2. Use explicit mappings from tf-cfn-mappings.yaml
    3. Fall back to name similarity matching
    
    AI ASSISTANT: If you see many false positives in tf_only:
    - Check if resources exist in CFN with different names
    - Add mappings to tf-cfn-mappings.yaml
    - Add skip patterns for intentionally different resources
    """
    config = config or MappingConfig()
    matches = []
    tf_only = []
    skipped_tf = []
    cfn_only = list(cfn_resources)
    
    # Build CFN lookup by logical ID and type
    cfn_by_id = {cfn.logical_id: cfn for cfn in cfn_resources}
    cfn_by_type = {}
    for cfn in cfn_resources:
        cfn_by_type.setdefault(cfn.type, []).append(cfn)
    
    for tf in tf_resources:
        # Get full address for pattern matching
        tf_address = tf.file.replace("plan:", "") if tf.file.startswith("plan:") else tf.address
        
        # Phase 1: Check skip patterns
        if should_skip_tf(tf_address, config):
            skipped_tf.append(tf)
            continue
        
        # Check if type is skipped
        cfn_type = tf.cfn_type
        if cfn_type == "SKIP":
            skipped_tf.append(tf)
            continue
        
        if cfn_type.startswith("UNKNOWN:"):
            tf_only.append(tf)
            continue
        
        # Phase 2: Check explicit mappings
        mapped_cfn_id = find_mapping(tf_address, config)
        if mapped_cfn_id and mapped_cfn_id in cfn_by_id:
            cfn = cfn_by_id[mapped_cfn_id]
            if cfn in cfn_only:
                matches.append((tf, cfn, 1.0))  # Perfect match via mapping
                cfn_only.remove(cfn)
                continue
        
        # Phase 3: Fall back to name similarity
        candidates = cfn_by_type.get(cfn_type, [])
        best_match = None
        best_score = 0
        
        for cfn in candidates:
            if cfn not in cfn_only:
                continue
            score = name_similarity(tf.name, cfn.logical_id)
            if score > best_score and score > 0.3:
                best_score = score
                best_match = cfn
        
        if best_match:
            matches.append((tf, best_match, best_score))
            cfn_only.remove(best_match)
        else:
            tf_only.append(tf)
    
    return {
        "matches": matches, 
        "tf_only": tf_only, 
        "cfn_only": cfn_only,
        "skipped_tf": skipped_tf,
    }


def name_similarity(tf_name: str, cfn_id: str) -> float:
    """Calculate name similarity score"""
    tf_norm = tf_name.lower().replace("-", "").replace("_", "")
    cfn_norm = cfn_id.lower().replace("-", "").replace("_", "")
    
    if tf_norm == cfn_norm:
        return 1.0
    if tf_norm in cfn_norm or cfn_norm in tf_norm:
        return 0.8
    
    # Check word overlap
    tf_words = set(re.split(r'[-_]', tf_name.lower()))
    cfn_words = set(re.split(r'(?=[A-Z])', cfn_id))
    cfn_words = {w.lower() for w in cfn_words if w}
    
    if tf_words & cfn_words:
        return len(tf_words & cfn_words) / max(len(tf_words), len(cfn_words))
    
    return 0.0


def generate_task_file(task_num: int, action: str, tf_res: TFResource, 
                       cfn_res: CFNResource = None, output_dir: Path = None) -> str:
    """Generate a focused task file for agent consumption"""
    
    task_id = f"{task_num:03d}"
    if action == "ADD":
        filename = f"{task_id}-add-{tf_res.type.replace('aws_', '')}-{tf_res.name}.md"
    elif action == "UPDATE":
        filename = f"{task_id}-update-{cfn_res.logical_id}.md"
    else:
        filename = f"{task_id}-review-{cfn_res.logical_id if cfn_res else tf_res.name}.md"
    
    lines = [
        f"# Task {task_id}: {action} Resource",
        "",
        f"**Action**: {action}",
        f"**Priority**: {'HIGH' if 'ecs_service' in (tf_res.type if tf_res else '') else 'MEDIUM'}",
        "",
    ]
    
    if tf_res:
        lines.extend([
            "## Terraform Source",
            "",
            f"- **File**: `terraform/aws-ecs/{tf_res.file}`",
            f"- **Line**: {tf_res.line}",
            f"- **Address**: `{tf_res.address}`",
            f"- **Type**: `{tf_res.type}` → `{tf_res.cfn_type}`",
            "",
            "### TF Resource Block",
            "```hcl",
            tf_res.raw_block[:2000] if tf_res.raw_block else "# Could not extract block",
            "```",
            "",
        ])
    
    if cfn_res:
        lines.extend([
            "## CloudFormation Target",
            "",
            f"- **File**: `cloudformation/aws-ecs/{cfn_res.file}`",
            f"- **Logical ID**: `{cfn_res.logical_id}`",
            f"- **Type**: `{cfn_res.type}`",
            "",
            "### CFN Resource Block",
            "```yaml",
            cfn_res.raw_block[:2000] if cfn_res.raw_block else "# Could not extract block",
            "```",
            "",
        ])
    
    if action == "ADD":
        if tf_res.cfn_type.startswith("UNKNOWN:"):
            lines.extend([
                "## ⚠️ Unknown CFN Type",
                "",
                f"The Terraform type `{tf_res.type}` is not in the type mapping.",
                "",
                "**Action required**:",
                f"1. Find the equivalent AWS::* CloudFormation type for `{tf_res.type}`",
                "2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`",
                "3. Re-run the sync tool",
                "",
            ])
        else:
            lines.extend([
                "## Suggested CFN Template",
                "",
                f"Add to: `cloudformation/aws-ecs/templates/{suggest_cfn_file(tf_res)}`",
                "",
                "```yaml",
                generate_cfn_snippet(tf_res),
                "```",
                "",
            ])
    
    lines.extend([
        "## Instructions",
        "",
    ])
    
    if action == "ADD":
        lines.append(f"1. Add the resource `{tf_res.suggested_cfn_id}` to the appropriate CFN template")
        lines.append("2. Update any !Ref placeholders with actual resource references")
        lines.append("3. Add to Outputs if needed by other stacks")
    elif action == "UPDATE":
        lines.append("1. Compare TF and CFN properties for drift")
        lines.append("2. Update CFN to match TF configuration")
        lines.append("3. Test deployment in dev environment")
    
    content = "\n".join(lines)
    
    if output_dir:
        task_file = output_dir / "tasks" / filename
        task_file.parent.mkdir(parents=True, exist_ok=True)
        task_file.write_text(content)
    
    return content


def suggest_cfn_file(tf_res: TFResource) -> str:
    """Suggest which CFN template file a resource belongs in"""
    t = tf_res.type
    
    if any(x in t for x in ["vpc", "subnet", "gateway", "route", "security_group", "endpoint"]):
        return "network-stack.yaml"
    if any(x in t for x in ["efs", "rds", "db_", "secretsmanager", "ssm_parameter", "kms"]):
        return "data-stack.yaml"
    if any(x in t for x in ["ecs_cluster", "ecr", "lb", "alb", "target_group", "listener", "iam"]):
        return "compute-stack.yaml"
    if any(x in t for x in ["ecs_service", "ecs_task", "autoscaling"]):
        return "services-stack.yaml"
    
    return "compute-stack.yaml"  # default


def generate_cfn_snippet(tf_res: TFResource) -> str:
    """Generate a CFN YAML snippet from TF resource"""
    cfn_type = tf_res.cfn_type
    logical_id = tf_res.suggested_cfn_id
    
    # Basic template
    lines = [
        f"  {logical_id}:",
        f"    Type: {cfn_type}",
        "    Properties:",
    ]
    
    # Add common properties based on type
    props = tf_res.properties
    
    if "aws_db_proxy" in tf_res.type:
        lines.extend([
            f"      DBProxyName: !Sub ${{EnvironmentName}}-{tf_res.name}-proxy",
            f"      EngineFamily: {props.get('engine_family', 'MYSQL')}",
            "      Auth:",
            "        - AuthScheme: SECRETS",
            "          SecretArn: !Ref KeycloakDbSecret  # TODO: verify reference",
            "          IAMAuth: DISABLED",
            "      RoleArn: !GetAtt RdsProxyRole.Arn",
            "      VpcSubnetIds:",
            "        - !Ref PrivateSubnet1",
            "        - !Ref PrivateSubnet2", 
            "        - !Ref PrivateSubnet3",
            "      VpcSecurityGroupIds:",
            "        - !Ref DatabaseSG",
            f"      RequireTLS: {str(props.get('require_tls', False)).lower()}",
        ])
    elif "aws_ecs_service" in tf_res.type:
        lines.extend([
            f"      ServiceName: !Sub ${{EnvironmentName}}-{tf_res.name}",
            "      Cluster: !Ref MainEcsCluster  # TODO: verify reference",
            "      TaskDefinition: !Ref TODO_TaskDefinition",
            f"      DesiredCount: {props.get('desired_count', 1)}",
            "      LaunchType: FARGATE",
        ])
    elif "aws_ecs_cluster" in tf_res.type:
        lines.extend([
            f"      ClusterName: !Sub ${{EnvironmentName}}-{tf_res.name}",
        ])
    elif "aws_security_group" in tf_res.type:
        lines.extend([
            f"      GroupDescription: {props.get('description', 'TODO')}",
            "      VpcId: !Ref VPC  # TODO: verify reference",
        ])
    elif "aws_secretsmanager_secret" in tf_res.type:
        lines.extend([
            f"      Name: !Sub ${{EnvironmentName}}-{tf_res.name}",
        ])
    elif "aws_rds_cluster" in tf_res.type:
        lines.extend([
            f"      DBClusterIdentifier: !Sub ${{EnvironmentName}}-{tf_res.name}",
            f"      Engine: {props.get('engine', 'aurora-mysql')}",
            "      MasterUsername: !Ref KeycloakDatabaseUsername",
            "      MasterUserPassword: !Ref KeycloakDatabasePassword",
            "      DBSubnetGroupName: !Ref DbSubnetGroup",
            "      VpcSecurityGroupIds:",
            "        - !Ref DatabaseSG",
        ])
    elif "aws_cloudwatch_metric_alarm" in tf_res.type:
        lines.extend([
            f"      AlarmName: !Sub ${{EnvironmentName}}-{tf_res.name}",
            f"      AlarmDescription: {props.get('alarm_description', 'TODO')}",
            f"      MetricName: {props.get('metric_name', 'TODO')}",
            f"      Namespace: {props.get('namespace', 'TODO')}",
            f"      Statistic: {props.get('statistic', 'Average')}",
            f"      Period: {props.get('period', 300)}",
            f"      EvaluationPeriods: {props.get('evaluation_periods', 2)}",
            f"      Threshold: {props.get('threshold', 80)}",
            f"      ComparisonOperator: {props.get('comparison_operator', 'GreaterThanThreshold')}",
        ])
    else:
        lines.append("      # TODO: Add properties from TF resource")
    
    return "\n".join(lines)


def generate_summary(results: dict, output_dir: Path, mapping_config: MappingConfig = None) -> str:
    """Generate summary markdown file with AI assistant instructions"""
    matches = results["matches"]
    tf_only = results["tf_only"]
    cfn_only = results["cfn_only"]
    skipped_tf = results.get("skipped_tf", [])
    
    lines = [
        "# TF-CFN Sync Summary",
        "",
        f"Generated: {__import__('datetime').datetime.now().isoformat()}",
        "",
        "## AI Assistant Instructions",
        "",
        "When reviewing this summary:",
        "1. **TF Only resources**: Check if they exist in CFN with different names",
        "   - If yes: Add mapping to `tf-cfn-mappings.yaml`",
        "   - If intentionally TF-only: Add to `skip_tf_patterns` in mappings file",
        "   - If real gap: Add to CFN templates",
        "2. **Low-confidence matches**: Verify the TF↔CFN pairing is correct",
        "3. **After changes**: Re-run sync tool to verify improvements",
        "",
        "## Overview",
        "",
        "| Category | Count | Action |",
        "|----------|-------|--------|",
        f"| Matched | {len(matches)} | Review low-confidence matches |",
        f"| TF Only | {len(tf_only)} | Add to CFN or mappings file |",
        f"| CFN Only | {len(cfn_only)} | May be CFN-specific |",
        f"| Skipped | {len(skipped_tf)} | Intentionally different |",
        "",
    ]
    
    # Add known gaps section if any
    if mapping_config and mapping_config.known_gaps:
        lines.extend([
            "## Known Gaps (from mappings file)",
            "",
        ])
        for gap in mapping_config.known_gaps:
            lines.append(f"- **{gap.get('pattern', 'unknown')}**: {gap.get('description', '')}")
            lines.append(f"  - Recommendation: {gap.get('recommendation', 'N/A')}")
            lines.append(f"  - Priority: {gap.get('priority', 'unknown')}")
        lines.append("")
    
    lines.append("## Tasks Generated")
    lines.append("")
    
    task_num = 1
    
    if tf_only:
        lines.append("### Resources to Add")
        lines.append("")
        lines.append("These TF resources have no matching CFN resource. Either:")
        lines.append("- Add them to CFN templates")
        lines.append("- Add a mapping to `tf-cfn-mappings.yaml` if they exist with different names")
        lines.append("- Add to `skip_tf_patterns` if intentionally TF-only")
        lines.append("")
        for tf in sorted(tf_only, key=lambda x: x.type):
            tf_addr = tf.file.replace("plan:", "") if tf.file.startswith("plan:") else tf.address
            lines.append(f"- [ ] Task {task_num:03d}: ADD `{tf_addr}` → `{tf.suggested_cfn_id}`")
            task_num += 1
        lines.append("")
    
    if matches:
        low_confidence = [(tf, cfn, score) for tf, cfn, score in matches if score < 0.9]
        if low_confidence:
            lines.append("### Resources to Review for Drift")
            lines.append("")
            lines.append("These matches have low confidence scores. Verify they're correct:")
            lines.append("")
            for tf, cfn, score in sorted(low_confidence, key=lambda x: x[2]):
                lines.append(f"- [ ] Task {task_num:03d}: REVIEW `{tf.address}` ↔ `{cfn.logical_id}` (score: {score:.2f})")
                task_num += 1
            lines.append("")
    
    # Summary stats
    lines.extend([
        "## Statistics",
        "",
        f"- High-confidence matches (score >= 0.9): {len([m for m in matches if m[2] >= 0.9])}",
        f"- Low-confidence matches (score < 0.9): {len([m for m in matches if m[2] < 0.9])}",
        f"- Skipped via patterns: {len(skipped_tf)}",
        "",
    ])
    
    content = "\n".join(lines)
    
    summary_file = output_dir / "summary.md"
    summary_file.write_text(content)
    
    return content


def main():
    parser = argparse.ArgumentParser(description="Generate TF-CFN sync tasks")
    parser.add_argument("--tf-dir", default="terraform/aws-ecs", help="Terraform directory")
    parser.add_argument("--cfn-dir", default="cloudformation/aws-ecs", help="CloudFormation directory")
    parser.add_argument("--output", "-o", default="cloudformation/aws-ecs/sync-tasks", help="Output directory")
    parser.add_argument("--tf-plan", help="Path to terraform plan JSON file (more accurate than HCL parsing)")
    parser.add_argument("--mappings", default="cloudformation/aws-ecs/tf-cfn-mappings.yaml",
                        help="Path to manual TF-CFN mappings YAML file")
    parser.add_argument("--verbose", "-v", action="store_true")
    
    args = parser.parse_args()
    
    # Resolve paths
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent.parent.parent
    
    tf_dir = repo_root / args.tf_dir
    cfn_dir = repo_root / args.cfn_dir
    output_dir = repo_root / args.output
    mappings_path = repo_root / args.mappings
    
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "tasks").mkdir(exist_ok=True)
    
    # Load manual mappings
    print(f"Loading mappings: {mappings_path}", file=sys.stderr)
    mapping_config = load_mappings(mappings_path)
    
    # Parse Terraform - use plan JSON if provided, otherwise parse HCL
    if args.tf_plan:
        plan_path = Path(args.tf_plan)
        if not plan_path.is_absolute():
            plan_path = repo_root / plan_path
        print(f"Parsing Terraform plan JSON: {plan_path}", file=sys.stderr)
        tf_resources = parse_tf_plan_json(plan_path)
    else:
        print(f"Parsing Terraform HCL: {tf_dir}", file=sys.stderr)
        tf_resources = parse_tf_files(tf_dir)
    print(f"  Found {len(tf_resources)} resources", file=sys.stderr)
    
    print(f"Parsing CloudFormation: {cfn_dir}", file=sys.stderr)
    cfn_resources = parse_cfn_files(cfn_dir)
    print(f"  Found {len(cfn_resources)} resources", file=sys.stderr)
    
    print("Matching resources...", file=sys.stderr)
    results = match_resources(tf_resources, cfn_resources, mapping_config)
    print(f"  Matched: {len(results['matches'])}", file=sys.stderr)
    print(f"  TF only: {len(results['tf_only'])}", file=sys.stderr)
    print(f"  CFN only: {len(results['cfn_only'])}", file=sys.stderr)
    print(f"  Skipped (via mappings): {len(results.get('skipped_tf', []))}", file=sys.stderr)
    
    print(f"Generating tasks in {output_dir}...", file=sys.stderr)
    
    task_num = 1
    
    # Generate ADD tasks for TF-only resources
    unknown_types = []
    skipped_types = []
    for tf in results["tf_only"]:
        if tf.cfn_type.startswith("UNKNOWN:"):
            unknown_types.append(tf)
        elif tf.cfn_type == "SKIP":
            skipped_types.append(tf)
            continue  # Don't generate task for skipped types
        generate_task_file(task_num, "ADD", tf, output_dir=output_dir)
        task_num += 1
    
    # Report unknown types
    if unknown_types:
        print(f"\n⚠️  {len(unknown_types)} resources have unknown CFN type mappings:", file=sys.stderr)
        for tf in unknown_types:
            print(f"    {tf.type} -> Add to TF_TO_CFN mapping", file=sys.stderr)
    
    # Generate REVIEW tasks for low-confidence matches
    for tf, cfn, score in results["matches"]:
        if score < 0.9:
            generate_task_file(task_num, "UPDATE", tf, cfn, output_dir=output_dir)
            task_num += 1
    
    # Generate summary
    generate_summary(results, output_dir, mapping_config)
    
    print(f"Generated {task_num - 1} task files", file=sys.stderr)
    print(f"See {output_dir}/summary.md for overview", file=sys.stderr)


if __name__ == "__main__":
    main()
