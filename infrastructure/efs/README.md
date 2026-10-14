# EFS persistence stack

Gives the RSPS server **durable storage** for player saves. Fargate tasks are
disposable — each restart starts with an empty filesystem — so anything the game
writes to `/opt/lotica/data` (player accounts, clans, shops, lottery, logs) is
lost on every deploy or health-check replacement. This stack fixes that by
mounting a shared, network filesystem (EFS) at that path.

## What it creates

| Resource | Purpose |
|----------|---------|
| `aws_efs_file_system` | Managed, encrypted, elastic NFS — the durable store |
| `aws_efs_mount_target` (×2) | One network endpoint per AZ for tasks to connect to |
| `aws_security_group` | Allows NFS (2049) **only** from the ECS tasks SG |
| `aws_efs_access_point` | Pins a POSIX user + roots the app at `/lotica-data` |
| `aws_iam_role_policy` | Lets the task role mount/write EFS (IAM auth + TLS) |

## Why EFS (not EBS)?

An EBS disk attaches to one machine in one Availability Zone. A Fargate task is
disposable and may respawn on a different host or AZ. EFS is **networked** file
storage that any task in any AZ can mount — the right tool for shared, persistent
state on Fargate.

## How it connects to the app

`GameConstants.FILES_PATH` resolves to `/opt/lotica/data/` inside the Linux
container (see `src/.../game/GameConstants.java`). The task definition mounts the
EFS access point at exactly that path, so saves land on EFS with **no code
change**. (There is also a `GAME_DATA_PATH` env override if the path ever needs
to move.)

## Apply order

This stack must be applied **before** `ecs-task-definition`, which looks up the
file system and access point by name to mount them.

```bash
# 1. Create the EFS infrastructure
cd infrastructure/efs
terraform init && terraform apply

# 2. Publish a new task definition revision that mounts it
cd ../ecs-task-definition
terraform apply

# 3. Roll the service onto the new revision (billable Fargate run)
cd ../ecs-service
terraform apply        # or: aws ecs update-service --force-new-deployment ...
```

## Cost

Mount targets are free. Storage is ~$0.30/GB-month and saves are a few MB, so
the standing cost is effectively zero. Fargate compute is only billed while the
service `desired_count` is ≥ 1.

## Verifying persistence

1. Connect, create a character, log out (forces a save).
2. Force a new deployment (replaces the task).
3. Reconnect — the character still exists. Saves survived a fresh container.
