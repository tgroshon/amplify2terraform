#################
# Identity Pool #
#################

resource "aws_cognito_identity_pool" "main" {
  identity_pool_name               = "${var.app_name} ${var.stage}"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = "${aws_cognito_user_pool_client.web.id}"
    provider_name           = "cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
    server_side_token_check = false
  }
}

resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = "${aws_cognito_identity_pool.main.id}"

  roles = {
    "authenticated"   = "${aws_iam_role.cognito_authenticated.arn}"
    "unauthenticated" = "${aws_iam_role.cognito_unauthenticated.arn}"
  }
}

#############
# User Pool #
#############

resource "aws_cognito_user_pool" "main" {
  name = "${var.namespace}"

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_message        = "App: Your verification code is {####}"
    email_subject        = "App Verification Code"
  }

  auto_verified_attributes = ["email"]

  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 5
      max_length = 300
    }
  }

  password_policy {
    minimum_length    = 10
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }

  sms_configuration {
    external_id    = "${var.cognito_role_external_id}"
    sns_caller_arn = "${aws_iam_role.cognito_sns_role.arn}"
  }

  admin_create_user_config {
    allow_admin_create_user_only = true

    invite_message_template {
      sms_message   = "App Invitation. USR: {username} PWD: {####}  https://${var.site_domain}"
      email_subject = "App Invitation"

      email_message = <<EOF
You have been added to the App Application: https://${var.site_domain}
Username: {username}
Temporary Password: {####}

You will be asked to change your password after first logging in.
EOF
    }
  }

  tags = {
    Project = "${var.app_name}"
    Stage   = "${var.stage}"
  }
}

###############
# User Groups #
###############

resource "aws_cognito_user_group" "manager" {
  name         = "manager"
  user_pool_id = "${aws_cognito_user_pool.main.id}"
  description  = "Permission to send worker notifications"
}

###########
# Clients #
###########

resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.namespace}-client-web"
  user_pool_id = "${aws_cognito_user_pool.main.id}"
}

#######
# IAM #
#######

resource "aws_iam_role" "cognito_authenticated" {
  name = "${var.namespace}-cognito-authenticated"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "authenticated"
        }
      }
    }
  ]
}
EOF

  tags = {
    Project = "${var.app_name}"
    Stage   = "${var.stage}"
    Service = "cognito"
  }
}

resource "aws_iam_role" "cognito_unauthenticated" {
  name = "${var.namespace}-cognito-unauthenticated"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "unauthenticated"
        }
      }
    }
  ]
}
EOF

  tags = {
    Project = "${var.app_name}"
    Stage   = "${var.stage}"
    Service = "cognito"
  }
}

resource "aws_iam_role" "cognito_sns_role" {
  name = "${var.namespace}-cognito-sns-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "cognito-idp.amazonaws.com"
      },
      "Condition": {
        "StringEquals": {"sts:ExternalId": "${var.cognito_role_external_id}"}
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    Project = "${var.app_name}"
    Stage   = "${var.stage}"
    Service = "cognito"
  }
}

resource "aws_iam_policy" "cognito_sns_role" {
  name        = "${var.namespace}-cognito-sns-policy"
  description = "${var.namespace} Cognito allow SNS publish"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sns:Publish*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "cognito_sns_role" {
  name       = "${var.namespace}-cognito-sns-role-policy"
  roles      = ["${aws_iam_role.cognito_sns_role.name}"]
  policy_arn = "${aws_iam_policy.cognito_sns_role.arn}"
}
