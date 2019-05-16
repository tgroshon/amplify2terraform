# amplify2terraform

This repo is a proof-of-concept for using Amplify client libraries with Terraform (and serverless for Lambda functions) rather than Amplify CLI and Console.

See my blog for an explanation of _why_: https://tommygroshong.com/posts/appsync-cognito-cloudfront/

## Prereqs ##

Install the following tools:

 - [Terraform](https://www.terraform.io/downloads.html)
 - [Node.js](https://nodejs.org/en/)
 - [Yarn](https://yarnpkg.com/lang/en/docs/install/)
 - [Serverless](https://serverless.com/framework/docs/providers/aws/guide/installation/)
 - [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)

Setup AWS API credentials: `aws configure`

## Build ##

The build workflow is as follows:

 - Terraform infrastructure:
   * `cd terraform`
   * `terraform init` (only needed the first time)
   * `terraform apply`
 - Deploy serverless function:
   * `cd serverless`
   * `serverless deploy -v`
 - Build and push react app:
   * `terraform output -state=terraform/terraform.tfstate aws-exports-file > src/aws-exports.js`
   * `yarn build`
   * `aws s3 sync build s3://<YOURBUCKET> --cache-control max-age=300`

## Overview ##

### Infrastructure ###

My terraform scripts are in `terraform/` and the resources are organized thusly:

1. `main.tf`: Variables, Outputs, and Data resources
2. `api.tf`: DynamoDB; AppSync API, Data Sources, and Resolvers; IAM perms
3. `auth.tf`: Cognito Identity Pool, User Pool, User Groups, Clients, and IAM roles
4. `website.tf`: S3 website bucket, CloudFront distribution, Route 53 Record

Serverless functions are in `services/`. The code is just a dummy example. The `serverless.yml`
however shows a few useful examples:

1. Giving access to DynamoDB tables
2. Outputting your function ARNs so you can plug them into terraform as variables

When using these scripts in a non-toy app, I create multiple terraform workspaces
and separate `<stage>.tfvars` files for use with each. Not beautiful, but works.

### Client ###

The client app was bootstrapped with [Create React App](https://github.com/facebook/create-react-app).

It uses the `AppSyncClientSDK` which is an Apollo compatible client; just pass it to
your provider: `<ApolloProvider client={client} />`.

The pattern that Amplify and AppSync give you for configuring the Clients is having a
`src/aws-exports.js` file that is **ignored** from git and contains all your configuration
details for AppSync, Cognito, etc. My code does the same pattern except uses terraform
to generate that file:

    terraform output aws-exports-file > ../src/aws-exports.js

That was a trick I picked up for generating Kubeconfig files after setting up Kubernetes.
So after creating your infrastructure with terraform, you should generate the latest
`aws-exports.js` file.

NOTE: Generate the latest `aws-exports.js` file for your target stage before bundling code!

Your bundled code will essentially be hardcoded to point at whatever stage/environment
was referenced by `aws-exports.js` _at the time of bundling_. Notice in the instructions
above on how to _build and push react app_ it has you write the `src/aws-exports.js`
first. Those few lines are should go in a deploy script.
