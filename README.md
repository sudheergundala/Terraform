## TERRAFORM:

It is a tool which will provision the infrastructure via code. Uses HashiCrop Configuration Language.


Why are we using Terraform to Provision the infrastructure.
1. Supports Multi Cloud
2. Infrastructure as a code, Declarative and will be stored in centalized Version control system
3. Maintain the consistancy
4. Auditable code
5. Reusable modules
6. It remembers the infrastructure using statefile
7. we can see changes before it is applied 

## Provider:
  Terraform does nothing without providers.
It downloads provider plugins.
It uses the cloud APIs under the hood.  
Authunticate via env vars/IAM role.
  Best Practices:
Never Hardcode AWS credentials.
Always use:
   IAM Roles
   AWS_PROFILE
   OIDC (CI/CD)

--> Terraform init:
  when you execute this command it will Download Provider plugins, Initializes Backend and Setup the working directory.

  Terraform init installs provider plugins and configures the backend, but providers aren’t actually authenticated or used until plan/apply. Backend initialization happens even earlier and cannot depend on variables or providers, which is why backend configuration must be static.

### Terraform backend configuration.

If we observe backend.tf we will be hardcoding the values for bucket and dynamoDB table and that bucket and dynamodb table should be pre-exists before in AWS environment. 

How do that happen? Do we manually configure them in AWS? or does terraform create it? if terraform creates those bucket and dynamodb how the state is maintained here? 

The answer is yes it is created through the terraform code.

We use bootstrap for creating those resources in AWS. 

If terraform created those resources how about the state?

Here, the bootstrap will use the local state(terraform.tfstate) to create those resources during the terraform apply.
This run will happen only once at organization level. 
Once the resources (bucket and DynamoDB) are created, then the remote state will be stored in that for all the other projects using key to differentiate betweeen the environments and projects.

These bucket and DynamoDB resources will be used later during the configuration of backend.tf with individual projects during the terraform init. 

Steps to do that
   1. create a seperate project for bootstrap
   2. under that create a main.tf with the resources and varaible.tf to pass the values to it.
   3. when you run terraform init, it will initialize the backend configuration using the local state. Also downloads the provider plugins
   4. when you run terraform apply it will authenticate and authorize with the provider APIs and create the resources in the AWS account .
   it is a one time activity and those bucket and dynamoDb details will be used for other projects backend to configure the state.


### Why we are providing direct values to backend.tf instead of dynamic/varaible values

terraform init --> at this point terraform 
                   1. dont know your varaibles
                   2. does not evaluate expressions
                   3. does not load .tfvars
                   4. does not know providers  
                   It must do first
                   1. decide where the state lives
                   2. decide how to lock it
                   3. decide how to access it
  Here Terraform core will connect with AWS using the accesskeys not with the provider APIs. because , by this time terraform only will be downloading the provider plugins but not authenticate through it.
 
 so the decision cannot depends on varaibles because variables itself may live in remote state which you'r trying to configure.

terraform plan/apply ---> only after backend is configured
                        1. variables are loaded
                        2. providers are initialized
                        3. state is read
                        4. graph is built

**** so backend config must be statically resolvable before terraform knows anything else.


### Terraform State:
Terraform state is a state file which stores the resources and details/attributes of what it created. 
it is identity of what exact thing in AWS resource.
It will always compares this file before appying any changes.
It is the source of truth for the terraform. 
It is used for the drift comparision.
Without state terraform is blind.

Imp: Always store the state in remote, secure and lock.

For remote state in AWS, we use S3 bucket to store the statefile and for locking we will use DynamoDB table.
So before writing the backend.tf config we need to create them and it will be executed once.

The S3 bucket used for the state should be 
   1. blocked from public access
   2. enable versioning
   3. enable KMS encryption

## Why locking is Important?

If two people are working on the terraform and does the apply, then it will lead to corrupt state, race conditions, partial resource deployment and infra drift will happen.

With State locking, terraform will not allow multiple changes at a time. The first person who requested for the change will acquire the lock and other people will need to wait till it is done.

### How Terraform uses state

 when the terraform plan or apply is used 
   i. Reads .tf files (desired state)
   ii. Reads state file (last known snapshot)
   iii. Queries AWS (current reality)
   iv. Diff everything
   v. Produce execution plan

  while doing this it has the options of from the provider schema
     update in-place -- can be modified
     forcenew -- cannot be modified.so, need to destroy and recreate
     computed  --- values known only after apply
     optional  --- can be skipped
     create  -- brand new create
     destroy  -- delete 

  then it will build the DAG(Directed Acyclic Graph)

  Directed mean A --> B
  Acyclic mean no-loop

  ## order

What → diff (state vs AWS vs code)
How → in-place vs ForceNew
Order → DAG(Directed Acyclic Graph)


# Why Querying AWS?

State file ---> Snapshot taken last time Terraform successfully applied changes.
on AWS --> It is the live environment
1. Drift Detection
     Some one might manually done the changes directly in AWS. If not checked, terraform would assume infra is still correct and changes will go undetected and state would slowly become lies. 
2. Safety before changes
    By checking the AWS, terraform can understand whether it need to be changed and recreated.
    whenever terraform can apply a change for the resources already available on AWS, it has two options
      1. in-place update -- Attribute can be changed on an existing resource without destroying it.
      2. destroy and recreate -- if the attribute change ,the resource must be destroyed and recreated.
      for ex Security Group changes --> can be updated without changing anything.
             AMI changes ---> destroy and recreate. 
3. Dependency Graph Accuracy
    Some dependecies are dynamic. So terraform must query AWS to know what is currently attached and what must be detached first.
4. Import & Partial Knowledge
    Terraform does not know everything.
      ex: Defaults sets by AWS
          Resources imported from existing infra
    by querying AWS it populates the missing attributes and Normalize reality into state.


## Terraform Directed Acyclic Graph:

It is a directed (A -> B) Acyclic (noloops) graph.
 This means it determine the execution order and parallelism. 
 it is built from 
    Resource Reference
    Data Source
    implicit Dependencies
    explicit Depends_on

By Querying the AWS terraform updated the DAG.
  ex: aws_subnet.private --> terraform knows only this
     on AWS
     aws_subnet.private
        |    
     aws_network_interface.eni-123
         |
     aws_instance.app 


### Terraform State fail Scenarios and how can we recover:-
    1. State is wrong
    2. State is incorrect
    3. State is lost completely

















