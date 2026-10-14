# Shipping It Automatically: Keyless CI/CD to ECS

> Part of a documented learning lab. Costs are historical estimates from these sessions; later posts describe the additions to the initial architecture.
> [Project overview](../README.md) · [Part 1](README.md) · [Part 2](worlds.md) · [Part 3](observability.md) · [Part 4](cicd.md)


*Part 4 of putting a legacy Java RuneScape server on AWS. [Part 1](./README.md) got it onto Fargate, [Part 2](./worlds.md) made it multi world, and [Part 3](./observability.md) added monitoring. This post is how I stopped deploying by hand: a pipeline that builds, ships, and rolls the server with one click, with **no long-lived AWS access keys stored in GitHub.***

## TL;DR

* A **GitHub Actions** pipeline that builds the image, pushes it to **ECR**, and rolls the **ECS** service with one click.
* **Keyless** means no stored AWS keys. GitHub proves its identity to AWS with a temporary **OIDC** token and assumes a scoped IAM role.
* Getting it green meant debugging two *"works on my laptop, breaks in CI"* failures. That was the most useful part of the whole exercise.

## The problem: deploying by hand

Before this, shipping a change took about six manual steps: build the jar, run `docker build`, log in to ECR, tag the image, push it, then force a new deployment.

## What I built

A `workflow_dispatch` GitHub Actions workflow that runs manually. On each run:

```text
OIDC auth  →  ECR login  →  fetch game cache from S3  →  docker build
           →  push image with git SHA and latest tags  →  update ECS service
```

## Keyless with OIDC

The old way to let CI access AWS was to store **access keys** in GitHub. Those never expire. If they leak, someone has access to your account until you notice. That is a standing liability.

The new way is **OpenID Connect**, or **OIDC**:

```text
1. The workflow starts and GitHub creates a temporary, signed OIDC token
2. It gives that token to AWS and asks to assume an IAM role
3. The role trust policy verifies that the token came from my repository
4. AWS returns short-lived temporary credentials
5. The pipeline uses them to push to ECR and roll ECS
```

**Nothing long lived is stored anywhere.** If a token leaked, it would soon expire, and the trust is scoped to my specific repository. No other repository can assume the role.

### Least privilege

The role can do exactly two things: **push to one ECR repository** and **roll services in one cluster**, plus read the build cache from one S3 bucket. It cannot access anything else in the account. Scoping IAM this tightly is what separates a thoughtful setup from one that grants access to everything.

## The two clean room bugs

My local builds worked. The first CI runs did not, and both failures taught the same lesson: **a clean CI runner exposes hidden assumptions that your laptop was quietly satisfying.**

**1. The missing cache.** The Dockerfile uses `COPY data/cache`, but the 246 MB of game assets is correctly excluded from git because it is too large for version control. My laptop had it on disk, but the fresh CI clone did not. The `COPY` instruction found nothing, so the build failed. **Fix:** store the cache in **S3** and have the pipeline download it before building. Large build assets belong in object storage, not git.

**2. Exit code 126.** `./gradlew` failed with "permission denied." The wrapper script had lost its Unix executable permission because Git on Windows does not reliably preserve it. Linux CI enforces the permission, while my laptop did not. **Fix:** run `chmod +x gradlew` in the Dockerfile.

![The Deploy to ECS workflow run, green, manually triggered](./screenshots/cicd-green-run.png)

*The pipeline, green from beginning to end, from OIDC authentication through the ECS deployment.*

## What "deploy" actually means

The final step uses the AWS CLI to force a new ECS deployment. It does not hand ECS the image directly. It tells ECS to **start fresh tasks**, and each new task **pulls the new `:latest` image from ECR** when it starts. I also tag every image with the **git SHA**, so I can always trace which commit is running and roll back by deploying a known good SHA.

## Lessons

* **Automate the toil.** One click, identical every time, beats six manual steps and a typo.
* **Keyless beats stored keys.** OIDC means there are no long lived secrets to leak.
* **Use least privilege IAM.** Scope the role to exactly what it needs.
* **CI is a clean room.** It makes hidden local dependencies explicit, which is why a green pipeline means the build is genuinely reproducible.
