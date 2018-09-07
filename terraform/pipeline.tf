provider "aws" {
  profile = "cardpayments"
  region = "eu-west-1"
}

terraform {
  backend "s3" {
    bucket = "cardpayments-state"
    key = "smtpHal"
    region = "eu-west-1"
    profile = "cardpayments"
  }
}

resource "aws_s3_bucket" "cache" {
  bucket = "smtphal-cache"
  acl = "private"
}


resource "aws_s3_bucket" "build" {
  bucket = "smtpHal-build"
  acl = "private"
}


resource "aws_iam_role" "build-pipeline" {
  name = "build-pipeline"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role" "build-codebuild" {
  name = "build-app"
  assume_role_policy = <<EOF1
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF1
}

resource "aws_iam_role_policy" "build-vue-web" {
  role = "${aws_iam_role.build-codebuild.name}"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.cache.arn}",
        "${aws_s3_bucket.cache.arn}/*",
        "${aws_s3_bucket.build.arn}",
        "${aws_s3_bucket.build.arn}/*",
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [
        "${aws_codecommit_repository.web-app.arn}"
      ],
      "Action": "codecommit:*"
    },
    {
        "Effect": "Allow",
        "Action": "codecommit:ListRepositories",
        "Resource": "*"
    },
    {
        "Effect": "Allow",
        "Action": [
           "codebuild:*"
        ],
        "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "build-vue-pipeline" {
  role = "${aws_iam_role.build-pipeline.name}"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.build.arn}",
        "${aws_s3_bucket.build.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [
        "${aws_codecommit_repository.web-app.arn}"
      ],
      "Action": "codecommit:*"
    },
    {
        "Effect": "Allow",
        "Action": "codecommit:ListRepositories",
        "Resource": "*"
    },
    {
        "Effect": "Allow",
        "Action": [
           "codebuild:*"
        ],
        "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_codebuild_project" "vue-npm" {
  name = "vue-npm"
  service_role = "${aws_iam_role.build-codebuild.arn}"
  "artifacts" {
    type = "CODEPIPELINE"
  }
  "environment" {
    compute_type = "BUILD_GENERAL1_SMALL"
    image = "aws/codebuild/nodejs:10.1.0"
    type = "LINUX_CONTAINER"
  }
  "source" {
    type = "CODEPIPELINE"
  }
  cache {
    type = "S3"
    location = "${aws_s3_bucket.cache.bucket}"
  }
}

resource "aws_codepipeline" "web-app" {
  name = "web-app"
  "artifact_store" {
    location = "${aws_s3_bucket.build.bucket}"
    type = "S3"
  }
  role_arn = "${aws_iam_role.build-pipeline.arn}"
  "stage" {
    name = "source"
    action {
      category = "Source"
      name = "Source"
      owner = "AWS"
      provider = "CodeCommit"
      version = "1"
      output_artifacts = [
        "source"]
      configuration {
        RepositoryName = "${aws_codecommit_repository.web-app.repository_name}"
        BranchName = "master"
      }
    }
  },
  "stage" {
    name = "NPM_Build"
    "action" {
      input_artifacts = [
        "source"]
      output_artifacts = [
        "npm-dist"]
      category = "Build"
      name = "vue-build"
      owner = "AWS"
      provider = "CodeBuild"
      version = "1"
      configuration {
        ProjectName = "${aws_codebuild_project.vue-npm.name}"
      }
    }
  }
}
