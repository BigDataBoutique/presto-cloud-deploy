resource "aws_iam_role" "presto-service-role" {
  name_prefix = "presto-service-role"

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

resource "aws_iam_role_policy" "presto-service-policy" {
  name_prefix = "presto-service-policy"
  role        = aws_iam_role.presto-service-role.id

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
          "glue:BatchGetPartition",
          "glue:BatchCreatePartition",
          "glue:CreateDatabase",
          "glue:CreateTable",
          "glue:DeleteDatabase",
          "glue:DeletePartition",
          "glue:DeleteTable",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:GetTable",
          "glue:GetTables",
          "glue:UpdateTable",
          "glue:UpdatePartition"
        ],
        "Resource": "*"
    }
  ]
}
EOF

}

resource "aws_iam_instance_profile" "presto" {
  name_prefix = "presto-${var.environment_name}-ip"
  path        = "/"
  role        = aws_iam_role.presto-service-role.name
}
