resource "aws_iam_role" "trino-service-role" {
  name_prefix = "trino-service-role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Effect": "Allow"
    }
  ]
}
EOF

}

resource "aws_iam_role_policy" "trino-service-policy" {
  name_prefix = "trino-service-policy"
  role        = aws_iam_role.trino-service-role.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Resource": "*",
        "Action": [
            "cloudwatch:*",
            "ec2:DescribeInstances",
            "ec2:DescribeTags",
            "ec2:DescribeVolumes",
            "ec2:AttachVolume"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "s3:*"
        ],
        "Resource": ${jsonencode(var.s3_buckets)}
    },
    {
        "Effect": "Allow",
        "Action": [
            "glue:CreatePartition",
            "glue:BatchCreatePartition",
            "glue:CreateTable",
            "glue:DeleteTable",
            "glue:BatchDeleteTable",
            "glue:GetDatabase",
            "glue:GetDatabases",
            "glue:GetPartition",
            "glue:BatchGetPartition",
            "glue:GetPartitions",
            "glue:GetTable",
            "glue:GetTableVersions",
            "glue:GetTables",
            "glue:CreateBookmark",
            "glue:GetBookmark",
            "glue:UpdateBookmark",
            "glue:GetConnection",
            "glue:GetConnections"
        ],
        "Resource": "*"
    }
  ]
}
EOF

}

resource "aws_iam_instance_profile" "trino" {
  name_prefix = "trino-${var.environment_name}-ip"
  path        = "/"
  role        = aws_iam_role.trino-service-role.name
}
