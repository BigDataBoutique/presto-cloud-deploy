resource "aws_iam_role" "presto-service-role" {
  name = "presto-service-role"

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
  name = "presto-service-policy"
  role = "${aws_iam_role.presto-service-role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Resource": "*",
        "Action": [
            "cloudwatch:*",
            "ec2:DescribeInstances"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "s3:*"
        ],
        "Resource": ${jsonencode(var.s3_buckets)}
    }]
}
EOF
}
