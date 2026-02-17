### 🌍 Terraform – Infrastructure as Code (IaC)

Terraform is an Infrastructure as Code (IaC) tool created by HashiCorp that allows you to provision and manage infrastructure using code.

It uses HashiCorp Configuration Language (HCL) to declaratively define cloud and on-prem resources.

Instead of manually creating infrastructure in AWS Console, Azure Portal, or GCP UI, Terraform allows you to define everything in .tf files and apply it in a consistent, repeatable, and auditable way.

### 🚀 Why Do We Use Terraform?
      Terraform is widely used in production environments for the following reasons:

      1️⃣ Multi-Cloud Support

         Terraform supports multiple cloud providers like:
         Amazon Web Services
         Microsoft Azure
         Google Cloud Platform
         This allows organizations to manage infrastructure across different clouds using a single tool.

      2️⃣ Infrastructure as Code (Declarative)

         Infrastructure is defined in code.
         Code is stored in a centralized version control system (Git).
         Changes are tracked.
         Rollbacks are possible.
         Peer reviews are enabled.
         Terraform is declarative, meaning:
         You define what you want.
         Terraform decides how to create it.

      3️⃣ Consistency & Repeatability

         Same code → Same infrastructure.
         No configuration drift between environments.
         Dev, QA, Prod can be identical.

      4️⃣ Auditable Code

         Every infrastructure change is tracked in Git.
         You know:
         Who changed it
         When it was changed
         What was changed

      5️⃣ Reusable Modules

         You can create reusable modules for:
         VPC
         EKS
         IAM
         ALB
         Security Groups
         This promotes standardization across projects.

      6️⃣ State Management

         Terraform remembers infrastructure using a state file.
         Without state, Terraform is blind.

      7️⃣ Change Preview Before Apply

         You can run:
         terraform plan
         This shows what will change before applying it.

### 🔌 Providers

   Terraform itself does nothing without Providers.

      Providers:

         Are plugins
         Interact with cloud APIs
         Manage lifecycle of resources

      Example:

         provider "aws" {
         region = "us-east-1"
         }

      Under the hood, providers communicate with cloud APIs (like AWS APIs).

      🔐 Authentication Best Practices

         ❌ Never hardcode AWS credentials.
         ✅ Always use:
         IAM Roles
         AWS_PROFILE
         OIDC (for CI/CD pipelines)

### ⚙️ Terraform Init – What Actually Happens?

      When you run terraform init, Terraform will:

         Download provider plugins
         Initialize backend
         Set up working directory
         Important:
         Providers are downloaded but NOT authenticated yet.
         Backend initialization happens BEFORE providers are used.
         Backend configuration must be static.

     🗄 Terraform Backend Configuration

       Example:
      
         terraform {
         backend "s3" {
            bucket         = "org-terraform-state"
            key            = "prod/eks.tfstate"
            region         = "us-east-1"
            dynamodb_table = "terraform-locks"
            encrypt        = true
         }
         }
### ❓ Problem
         The S3 bucket and DynamoDB table must already exist.
         So how are they created?
## 🏗 Bootstrap Solution
   Yes — Terraform creates them.
   But not in the same project.
   We create a separate bootstrap project.
### 🔁 How Bootstrap Works

         Step 1: Create Bootstrap Project

            Contains:
            main.tf
            variables.tf
            This project creates:
            S3 bucket
            DynamoDB table

         Step 2: Use Local State Initially

            Bootstrap runs using local state (terraform.tfstate)
            terraform init
            terraform apply
            At this point:
            Backend = local
            State = local file
            S3 + DynamoDB get created
            This happens once at organization level.

         Step 3: Configure Remote Backend in Other Projects

            Now other projects can use:
            backend "s3" {
            bucket         = "org-terraform-state"
            key            = "dev/vpc.tfstate"
            region         = "us-east-1"
            dynamodb_table = "terraform-locks"
            }
            Each environment uses different key:
            dev/vpc.tfstate
            prod/eks.tfstate
            staging/app.tfstate
            Same bucket, different state files.

## ❓ Why Backend Cannot Use Variables?

      During terraform init:
      Terraform:
      Does NOT load variables
      Does NOT evaluate expressions
      Does NOT load .tfvars
      Does NOT initialize providers
      Terraform must first decide:
      Where state lives
      How to lock it
      How to access it
      Backend initialization happens before everything else.
      If backend depended on variables:
      Variables might be in remote state
      But remote state is not configured yet
      Circular dependency
      So backend configuration must be static and resolvable immediately.

### 📁 Terraform State

         Terraform state file:
         Stores resource identities
         Stores attributes
         Stores last applied snapshot
         It is the source of truth for Terraform.
         Terraform compares:
         Code
         State file
         Real cloud infrastructure
         Without state → Terraform cannot function properly.
### 🔐 Remote State Best Practices (AWS)
         For AWS:
         Use S3 bucket to store state
         Use DynamoDB table for locking
         S3 bucket must:
         Block public access
         Enable versioning
         Enable KMS encryption
### 🔒 Why State Locking is Important?
         If two engineers run terraform apply at same time:
         State corruption
         Race conditions
         Partial deployments
         Infrastructure drift
         With DynamoDB locking:
         First person acquires lock
         Others must wait
         Prevents corruption
### 🔄 How Terraform Uses State
      When running:
      terraform plan
      Terraform:
      Reads .tf files → Desired state
      Reads state file → Last snapshot
      Queries AWS → Current reality
      Compares everything
      Builds execution plan
### 🧠 Provider Schema Behavior
      Terraform checks provider schema and decides:
      update in-place → Modify resource without recreation
      ForceNew → Destroy and recreate
      computed → Value known after apply
      optional → Can be omitted
      create → New resource
      destroy → Delete resource
      Example:
      Security Group rule change → In-place update
      AMI change in EC2 → ForceNew (destroy + recreate)
### 🕸 Directed Acyclic Graph (DAG)
         Terraform builds a:
         Directed Acyclic Graph
         Directed → A → B
         Acyclic → No loops
         This determines:
         Execution order
         Parallelism
         Terraform builds DAG from:
         Resource references
         Data sources
         Implicit dependencies
         Explicit depends_on
### ❓ Why Does Terraform Query AWS?
         State file is only a snapshot.
         AWS is the real live system.
       Terraform queries AWS for:
         1️⃣ Drift Detection
            Someone may manually modify AWS.
            If Terraform does not check:
            State becomes incorrect
            Infrastructure drift occurs
         2️⃣ Safety Before Changes
            Terraform checks current live attributes.
            Then decides:
            In-place update
            Destroy and recreate
         3️⃣ Dependency Graph Accuracy
            Dependencies can change dynamically.
            Example:
            aws_subnet.private
                  |
            aws_network_interface.eni-123
                  |
            aws_instance.app
            Terraform queries AWS to understand real relationships before updating.
         4️⃣ Import & Partial Knowledge
            Terraform does not know:
            AWS default values
            Imported resources
            Dynamic attachments
         Querying AWS allows Terraform to:
            Populate missing attributes
            Normalize real infrastructure into state
### 📌 Execution Flow Summary
      Stage	What Happens
      init	Backend initialized, providers downloaded
      plan	State read, AWS queried, diff calculated
      apply	DAG executed respecting dependencies
### 🧩 Final Mental Model
      What → Diff (Code vs State vs AWS)
      How → In-place or ForceNew
      Order → DAG
### ✅ Production Rule
      Always use remote state
      Always enable locking
      Always secure state bucket
      Never hardcode credentials
      Use bootstrap project
      Store everything in Git















