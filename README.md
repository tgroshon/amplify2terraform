# amplify2terraform

This repo is a proof-of-concept for replacing Amplify CLI & Console with Terraform (and serverless for Lambda functions)

The client app was bootstrapped with [Create React App](https://github.com/facebook/create-react-app).

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
