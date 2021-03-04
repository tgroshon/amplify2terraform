###################
# DynamoDB Tables #
###################

resource "aws_dynamodb_table" "worker" {
  name         = "Worker-${var.namespace}-${var.stage}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Project = "${var.app_name}"
    Stage   = "${var.stage}"
  }
}

#######################
# AppSync GraphQL API #
#######################

resource "aws_appsync_graphql_api" "main" {
  name                = "${var.namespace}-api"
  authentication_type = "AMAZON_COGNITO_USER_POOLS"

  user_pool_config {
    user_pool_id   = "${aws_cognito_user_pool.main.id}"
    aws_region     = "${var.region}"
    default_action = "ALLOW"
  }

  schema = "${file("../schema.graphql")}"
}

################
# Data Sources #
################

resource "aws_appsync_datasource" "worker" {
  name             = "WorkerTable"
  api_id           = "${aws_appsync_graphql_api.main.id}"
  service_role_arn = "${aws_iam_role.appsync_dynamo_datasource.arn}"
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = "${aws_dynamodb_table.worker.name}"
  }
}

resource "aws_appsync_datasource" "notifier" {
  name             = "NotifierFunction"
  api_id           = "${aws_appsync_graphql_api.main.id}"
  service_role_arn = "${aws_iam_role.appsync_notifier_lambda_datasource.arn}"
  type             = "AWS_LAMBDA"

  lambda_config {
    function_arn = "${var.notifier_fn_arn}"
  }
}

#############
# Resolvers #
#############

resource "aws_appsync_resolver" "listWorkers" {
  api_id            = "${aws_appsync_graphql_api.main.id}"
  field             = "listWorkers"
  type              = "Query"
  data_source       = "${aws_appsync_datasource.worker.name}"
  request_template  = "${file("../resolvers/Query.listWorkers.req.vtl")}"
  response_template = "${file("../resolvers/Query.listWorkers.res.vtl")}"
}

resource "aws_appsync_resolver" "createWorker" {
  api_id            = "${aws_appsync_graphql_api.main.id}"
  field             = "createWorker"
  type              = "Mutation"
  data_source       = "${aws_appsync_datasource.worker.name}"
  request_template  = "${file("../resolvers/Mutation.createWorker.req.vtl")}"
  response_template = "${file("../resolvers/Mutation.createWorker.res.vtl")}"
}

resource "aws_appsync_resolver" "updateWorker" {
  api_id            = "${aws_appsync_graphql_api.main.id}"
  field             = "updateWorker"
  type              = "Mutation"
  data_source       = "${aws_appsync_datasource.worker.name}"
  request_template  = "${file("../resolvers/Mutation.updateWorker.req.vtl")}"
  response_template = "${file("../resolvers/Mutation.updateWorker.res.vtl")}"
}

resource "aws_appsync_resolver" "deleteWorker" {
  api_id            = "${aws_appsync_graphql_api.main.id}"
  field             = "deleteWorker"
  type              = "Mutation"
  data_source       = "${aws_appsync_datasource.worker.name}"
  request_template  = "${file("../resolvers/Mutation.deleteWorker.req.vtl")}"
  response_template = "${file("../resolvers/Mutation.deleteWorker.res.vtl")}"
}

resource "aws_appsync_resolver" "notifyWorker" {
  api_id            = "${aws_appsync_graphql_api.main.id}"
  field             = "notifyWorker"
  type              = "Mutation"
  data_source       = "${aws_appsync_datasource.notifier.name}"
  request_template  = "${file("../resolvers/Mutation.notifyWorker.req.vtl")}"
  response_template = "${file("../resolvers/Mutation.notifyWorker.res.vtl")}"
}

#######
# IAM #
#######

resource "aws_iam_role" "appsync_dynamo_datasource" {
  name = "${var.namespace}-dynamo-datasource"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

  tags {
    Project = "${var.app_name}"
    Stage   = "${var.stage}"
  }
}

resource "aws_iam_role_policy" "appsync_dynamo_datasource" {
  name = "${var.namespace}-dynamo-datasource"
  role = "${aws_iam_role.appsync_dynamo_datasource.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:GetItem",
        "dynamodb:Scan",
        "dynamodb:Query",
        "dynamodb:UpdateItem"
      ],
      "Resource": [
        "${aws_dynamodb_table.worker.arn}",
        "${aws_dynamodb_table.worker.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "appsync_notifier_lambda_datasource" {
  name = "${var.namespace}-notifier-datasource"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags {
    Project = "${var.app_name}"
    Stage   = "${var.stage}"
  }
}

resource "aws_iam_role_policy" "appsync_notifier_lambda_datasource" {
  name = "${var.namespace}-notifier-invocation"
  role = "${aws_iam_role.appsync_notifier_lambda_datasource.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": [
        "${var.notifier_fn_arn}"
      ]
    }
  ]
}
EOF
}
