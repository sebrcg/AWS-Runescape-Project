"""
Pulumi (Python) port of the RSPS ECS Fargate stack.

This single program reproduces what the Terraform code spreads across four
separately-applied stacks:

    infrastructure/ecr                -> ECR repository + lifecycle policy
    infrastructure/ecs-cluster        -> VPC, subnets, IGW/NAT, IAM, cluster
    infrastructure/ecs-task-definition-> task definition + log group
    infrastructure/ecs-service        -> the ECS service

The Terraform stacks are loosely coupled: each one re-discovers the others at
apply time via `data` lookups on tag names (e.g. `data "aws_vpc" { filter
tag:Name }`). Here we keep everything in one program and pass the *actual
resource objects* around (`vpc.id`, `cluster.arn`, `repo.repository_url`), so
the dependency graph is explicit and there are no magic-string lookups.
"""

import ipaddress
import json

import pulumi
import pulumi_aws as aws

# ---------------------------------------------------------------------------
# Config (values live in Pulumi.dev.yaml; see that file for the .tfvars mapping)
# ---------------------------------------------------------------------------
cfg = pulumi.Config()

environment = cfg.get("environment") or "prod"
cluster_name = cfg.get("clusterName") or "rsps-cluster"
repository_name = cfg.get("repositoryName") or "rsps-server"
vpc_cidr = cfg.get("vpcCidr") or "10.0.0.0/16"
log_retention_days = cfg.get_int("logRetentionDays") or 7

task_family = cfg.get("taskFamily") or "rsps-server"
service_name = cfg.get("serviceName") or "rsps-service"
cpu = cfg.get("cpu") or "1024"
memory = cfg.get("memory") or "2048"

game_port = cfg.get_int("gamePort") or 43594
js5_port = cfg.get_int("js5Port") or 43595

desired_count = cfg.get_int("desiredCount")
desired_count = 0 if desired_count is None else desired_count
assign_public_ip = cfg.get_bool("assignPublicIp")
assign_public_ip = True if assign_public_ip is None else assign_public_ip
enable_nat_gateway = cfg.get_bool("enableNatGateway") or False

region = aws.get_region().name
account_id = aws.get_caller_identity().account_id

# ===========================================================================
# 1) ECR  (mirrors infrastructure/ecr)
# ===========================================================================
repo = aws.ecr.Repository(
    "rsps-server",
    name=repository_name,
    image_tag_mutability="MUTABLE",
    image_scanning_configuration=aws.ecr.RepositoryImageScanningConfigurationArgs(
        scan_on_push=True,
    ),
    encryption_configurations=[
        aws.ecr.RepositoryEncryptionConfigurationArgs(encryption_type="AES256"),
    ],
    tags={
        "Name": "RSPS Server Container Registry",
        "Component": "Container-Registry",
    },
)

aws.ecr.LifecyclePolicy(
    "rsps-server-policy",
    repository=repo.name,
    policy=json.dumps(
        {
            "rules": [
                {
                    "rulePriority": 1,
                    "description": "Keep last 10 tagged images",
                    "selection": {
                        "tagStatus": "tagged",
                        "tagPrefixList": ["v", "release-"],
                        "countType": "imageCountMoreThan",
                        "countNumber": 10,
                    },
                    "action": {"type": "expire"},
                },
                {
                    "rulePriority": 2,
                    "description": "Keep only 3 untagged images",
                    "selection": {
                        "tagStatus": "untagged",
                        "countType": "imageCountMoreThan",
                        "countNumber": 3,
                    },
                    "action": {"type": "expire"},
                },
                {
                    "rulePriority": 3,
                    "description": "Expire images older than 30 days",
                    "selection": {
                        "tagStatus": "any",
                        "countType": "sinceImagePushed",
                        "countUnit": "days",
                        "countNumber": 30,
                    },
                    "action": {"type": "expire"},
                },
            ]
        }
    ),
)

# ===========================================================================
# 2) NETWORKING + CLUSTER + IAM  (mirrors infrastructure/ecs-cluster)
# ===========================================================================

# --- VPC ---
vpc = aws.ec2.Vpc(
    "main",
    cidr_block=vpc_cidr,
    enable_dns_hostnames=True,
    enable_dns_support=True,
    tags={"Name": f"{cluster_name}-vpc"},
)

igw = aws.ec2.InternetGateway(
    "main",
    vpc_id=vpc.id,
    tags={"Name": f"{cluster_name}-igw"},
)

# Two AZs for high availability (TF used data.aws_availability_zones).
azs = aws.get_availability_zones(state="available").names[:2]

# cidrsubnet(vpc_cidr, 8, n) -> a /24 inside the /16. ipaddress gives us the
# same deterministic split Terraform's cidrsubnet() produces.
_net = ipaddress.ip_network(vpc_cidr)
_subnets = list(_net.subnets(new_prefix=_net.prefixlen + 8))

public_subnets = []
private_subnets = []
for i in range(2):
    public_subnets.append(
        aws.ec2.Subnet(
            f"public-{i}",
            vpc_id=vpc.id,
            cidr_block=str(_subnets[i]),            # 10.0.0.0/24, 10.0.1.0/24
            availability_zone=azs[i],
            map_public_ip_on_launch=True,
            tags={"Name": f"{cluster_name}-public-subnet-{i + 1}", "Type": "Public"},
        )
    )
    private_subnets.append(
        aws.ec2.Subnet(
            f"private-{i}",
            vpc_id=vpc.id,
            cidr_block=str(_subnets[i + 10]),       # 10.0.10.0/24, 10.0.11.0/24
            availability_zone=azs[i],
            tags={"Name": f"{cluster_name}-private-subnet-{i + 1}", "Type": "Private"},
        )
    )

# --- Public route table -> IGW ---
public_rt = aws.ec2.RouteTable(
    "public",
    vpc_id=vpc.id,
    routes=[aws.ec2.RouteTableRouteArgs(cidr_block="0.0.0.0/0", gateway_id=igw.id)],
    tags={"Name": f"{cluster_name}-public-rt"},
)
for i, subnet in enumerate(public_subnets):
    aws.ec2.RouteTableAssociation(
        f"public-{i}", subnet_id=subnet.id, route_table_id=public_rt.id
    )

# --- Optional NAT Gateway (off by default to save ~$32/mo) ---
private_default_route = None
if enable_nat_gateway:
    eip = aws.ec2.Eip(
        "nat", domain="vpc", tags={"Name": f"{cluster_name}-nat-eip"},
        opts=pulumi.ResourceOptions(depends_on=[igw]),
    )
    nat = aws.ec2.NatGateway(
        "main",
        allocation_id=eip.id,
        subnet_id=public_subnets[0].id,
        tags={"Name": f"{cluster_name}-nat"},
        opts=pulumi.ResourceOptions(depends_on=[igw]),
    )
    private_default_route = aws.ec2.RouteTableRouteArgs(
        cidr_block="0.0.0.0/0", nat_gateway_id=nat.id
    )
else:
    # No NAT: private subnets route to the IGW (works only because tasks get a
    # public IP via assign_public_ip). Cheaper, slightly less "private".
    private_default_route = aws.ec2.RouteTableRouteArgs(
        cidr_block="0.0.0.0/0", gateway_id=igw.id
    )

private_rt = aws.ec2.RouteTable(
    "private",
    vpc_id=vpc.id,
    routes=[private_default_route],
    tags={"Name": f"{cluster_name}-private-rt"},
)
for i, subnet in enumerate(private_subnets):
    aws.ec2.RouteTableAssociation(
        f"private-{i}", subnet_id=subnet.id, route_table_id=private_rt.id
    )

# --- Security group for the ECS tasks ---
ecs_sg = aws.ec2.SecurityGroup(
    "ecs-tasks",
    name=f"{cluster_name}-ecs-tasks-sg",
    description="Security group for ECS tasks",
    vpc_id=vpc.id,
    ingress=[
        aws.ec2.SecurityGroupIngressArgs(
            description="RSPS Game Port",
            from_port=game_port, to_port=game_port,
            protocol="tcp", cidr_blocks=["0.0.0.0/0"],
        ),
        aws.ec2.SecurityGroupIngressArgs(
            description="RSPS JS5 Port",
            from_port=js5_port, to_port=js5_port,
            protocol="tcp", cidr_blocks=["0.0.0.0/0"],
        ),
    ],
    egress=[
        aws.ec2.SecurityGroupEgressArgs(
            description="Allow all outbound",
            from_port=0, to_port=0, protocol="-1", cidr_blocks=["0.0.0.0/0"],
        ),
    ],
    tags={"Name": f"{cluster_name}-ecs-tasks-sg"},
)

# --- CloudWatch log group for the cluster ---
cluster_log_group = aws.cloudwatch.LogGroup(
    "ecs",
    name=f"/ecs/{cluster_name}",
    retention_in_days=log_retention_days,
    tags={"Name": f"{cluster_name}-logs"},
)

# --- ECS cluster + Fargate capacity providers ---
cluster = aws.ecs.Cluster(
    "main",
    name=cluster_name,
    settings=[aws.ecs.ClusterSettingArgs(name="containerInsights", value="enabled")],
    tags={"Name": cluster_name, "Description": "ECS Fargate cluster for RSPS server"},
)

aws.ecs.ClusterCapacityProviders(
    "main",
    cluster_name=cluster.name,
    capacity_providers=["FARGATE", "FARGATE_SPOT"],
    default_capacity_provider_strategies=[
        aws.ecs.ClusterCapacityProvidersDefaultCapacityProviderStrategyArgs(
            capacity_provider="FARGATE", weight=1, base=1,
        )
    ],
)

# --- IAM: task execution role (used by ECS agent to pull image + ship logs) ---
assume_ecs = json.dumps(
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Effect": "Allow",
                "Principal": {"Service": "ecs-tasks.amazonaws.com"},
            }
        ],
    }
)

execution_role = aws.iam.Role(
    "ecs-task-execution",
    name=f"{cluster_name}-task-execution-role",
    assume_role_policy=assume_ecs,
    tags={"Name": f"{cluster_name}-task-execution-role"},
)

aws.iam.RolePolicyAttachment(
    "ecs-task-execution-managed",
    role=execution_role.name,
    policy_arn="arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
)

aws.iam.RolePolicy(
    "ecs-task-execution-ecr",
    name=f"{cluster_name}-ecr-access",
    role=execution_role.id,
    policy=cluster_log_group.arn.apply(
        lambda arn: json.dumps(
            {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Action": [
                            "ecr:GetAuthorizationToken",
                            "ecr:BatchCheckLayerAvailability",
                            "ecr:GetDownloadUrlForLayer",
                            "ecr:BatchGetImage",
                        ],
                        "Resource": "*",
                    },
                    {
                        "Effect": "Allow",
                        "Action": ["logs:CreateLogStream", "logs:PutLogEvents"],
                        "Resource": f"{arn}:*",
                    },
                ],
            }
        )
    ),
)

# --- IAM: task role (assumed by the application itself) ---
task_role = aws.iam.Role(
    "ecs-task",
    name=f"{cluster_name}-task-role",
    assume_role_policy=assume_ecs,
    tags={"Name": f"{cluster_name}-task-role"},
)

aws.iam.RolePolicy(
    "ecs-task-policy",
    name=f"{cluster_name}-task-policy",
    role=task_role.id,
    policy=json.dumps(
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": ["s3:GetObject", "s3:PutObject"],
                    "Resource": f"arn:aws:s3:::{cluster_name}-data/*",
                }
            ],
        }
    ),
)

# ===========================================================================
# 3) TASK DEFINITION  (mirrors infrastructure/ecs-task-definition)
# ===========================================================================
task_log_group = aws.cloudwatch.LogGroup(
    "task",
    name=f"/ecs/{task_family}",
    retention_in_days=log_retention_days,
    tags={"Name": f"{task_family}-logs", "Environment": environment},
)

# container_definitions is JSON. Several fields are Outputs (image URL, log
# group name), so we use Output.json_dumps which resolves them before encoding
# — the Pulumi equivalent of Terraform's jsonencode([...]) over interpolations.
container_definitions = pulumi.Output.json_dumps(
    [
        {
            "name": "rsps-server",
            "image": repo.repository_url.apply(lambda url: f"{url}:latest"),
            "essential": True,
            "portMappings": [
                {"containerPort": game_port, "hostPort": game_port,
                 "protocol": "tcp", "name": "game-port"},
                {"containerPort": js5_port, "hostPort": js5_port,
                 "protocol": "tcp", "name": "js5-port"},
            ],
            "environment": [
                {"name": "JAVA_OPTS", "value": "-Xmx1536m -Xms1536m"},
                {"name": "SERVER_PORT", "value": str(game_port)},
                {"name": "JS5_PORT", "value": str(js5_port)},
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": task_log_group.name,
                    "awslogs-region": region,
                    "awslogs-stream-prefix": "ecs",
                },
            },
            "healthCheck": {
                "command": ["CMD-SHELL", f"bash -c 'exec 3<>/dev/tcp/127.0.0.1/{game_port}' || exit 1"],
                "interval": 30,
                "timeout": 5,
                "retries": 3,
                "startPeriod": 120,
            },
        }
    ]
)

task_definition = aws.ecs.TaskDefinition(
    "rsps-server",
    family=task_family,
    network_mode="awsvpc",
    requires_compatibilities=["FARGATE"],
    cpu=cpu,
    memory=memory,
    execution_role_arn=execution_role.arn,
    task_role_arn=task_role.arn,
    container_definitions=container_definitions,
    tags={"Name": f"{task_family}-task-definition", "Environment": environment},
)

# ===========================================================================
# 4) SERVICE  (mirrors infrastructure/ecs-service)
# ===========================================================================
service = aws.ecs.Service(
    "rsps-server",
    name=service_name,
    cluster=cluster.arn,
    task_definition=task_definition.arn,
    desired_count=desired_count,
    launch_type="FARGATE",
    network_configuration=aws.ecs.ServiceNetworkConfigurationArgs(
        subnets=[s.id for s in private_subnets],
        security_groups=[ecs_sg.id],
        assign_public_ip=assign_public_ip,
    ),
    deployment_minimum_healthy_percent=100,
    deployment_maximum_percent=200,
    enable_execute_command=True,
    tags={"Name": service_name, "Environment": environment},
)

# ---------------------------------------------------------------------------
# Outputs (handy for `pulumi stack output` and for wiring into CI later)
# ---------------------------------------------------------------------------
pulumi.export("account_id", account_id)
pulumi.export("region", region)
pulumi.export("ecr_repository_url", repo.repository_url)
pulumi.export("vpc_id", vpc.id)
pulumi.export("public_subnet_ids", [s.id for s in public_subnets])
pulumi.export("private_subnet_ids", [s.id for s in private_subnets])
pulumi.export("cluster_name", cluster.name)
pulumi.export("task_definition_arn", task_definition.arn)
pulumi.export("service_name", service.name)
