resource "aws_db_subnet_group" "km_rds_subnet_grp" {
  name       = "km_rds_subnet_grp_${var.environment}"
  subnet_ids = var.private_subnet

  tags = merge(var.default_tags, {
    Name = "km_rds_subnet_grp_${var.environment}"
  })
}

resource "aws_security_group" "km_rds_sg" {
  name   = "km_rds_sg"
  vpc_id = var.vpc_id

  tags = merge(var.default_tags, {
    Name = "km_rds_sg_${var.environment}"
  })

  # HTTP access from anywhere
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  # Drata: Ensure that [aws_security_group.ingress.cidr_blocks] is explicitly defined and narrowly scoped to only allow traffic from trusted sources
  # Drata: Ensure that [aws_security_group.egress.cidr_blocks] is explicitly defined and narrowly scoped to only allow traffic to trusted sources
  }
}

resource "aws_kms_key" "km_db_kms_key" {
  # Drata: Define [aws_kms_key.policy] to restrict access to your resource. Follow the principal of minimum necessary access, ensuring permissions are scoped to trusted entities. Exclude this finding if access to Keys is managed using IAM policies instead of a Key policy
  description             = "KMS Key for DB instance ${var.environment}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(var.default_tags, {
    # Drata: Set [aws_kms_key.tags] to ensure that organization-wide tagging conventions are followed.
    Name = "km_db_kms_key_${var.environment}"
  })
}

resource "aws_db_instance" "km_db" {
  name                      = "km_db_${var.environment}"
  allocated_storage         = 20
  engine                    = "postgres"
  engine_version            = "10.6"
  instance_class            = "db.t3.medium"
  storage_type              = "gp2"
  password                  = var.db_password
  username                  = var.db_username
  vpc_security_group_ids    = [aws_security_group.km_rds_sg.id]
  db_subnet_group_name      = aws_db_subnet_group.km_rds_subnet_grp.id
  identifier                = "km-db-${var.environment}"
  storage_encrypted         = true
  skip_final_snapshot       = true
  final_snapshot_identifier = "km-db-${var.environment}-db-destroy-snapshot"
  kms_key_id                = aws_kms_key.km_db_kms_key.arn
  tags = merge(var.default_tags, {
    Name = "km_db_${var.environment}"
  })
}

resource "aws_ssm_parameter" "km_ssm_db_host" {
  name        = "/km-${var.environment}/DB_HOST"
  description = "Kai Monkey Database"
  type        = "SecureString"
  value       = aws_db_instance.km_db.endpoint

  tags = merge(var.default_tags, {})
}

resource "aws_ssm_parameter" "km_ssm_db_password" {
  name        = "/km-${var.environment}/DB_PASSWORD"
  description = "Kai Monkey Database Password"
  type        = "SecureString"
  value       = aws_db_instance.km_db.password

  tags = merge(var.default_tags, {})
}

resource "aws_ssm_parameter" "km_ssm_db_user" {
  name        = "/km-${var.environment}/DB_USER"
  description = "Kai Monkey Database Username"
  type        = "SecureString"
  value       = aws_db_instance.km_db.username

  tags = merge(var.default_tags, {})
}

resource "aws_ssm_parameter" "km_ssm_db_name" {
  name        = "/km-${var.environment}/DB_NAME"
  description = "Kai Monkey Database Name"
  type        = "SecureString"
  value       = aws_db_instance.km_db.name

  tags = merge(var.default_tags, {
    environment = "${var.environment}"
  })
}

resource "aws_s3_bucket" "km_blob_storage" {
  bucket = "km-blob-storage-${var.environment}"
  acl    = "private"
  tags = merge(var.default_tags, {
    # Drata: Set [aws_s3_bucket.tags] to ensure that organization-wide tagging conventions are followed.
    name = "km_blob_storage_${var.environment}"
  })
}

resource "aws_s3_bucket" "km_public_blob" {
  # Drata: Set [aws_s3_bucket.tags] to ensure that organization-wide tagging conventions are followed.
  # Drata: Set [s3.bucket.public_access_block_configuration] to true to prevent intentional or incidental public access. Exclude this finding if this configuration is set at the account level. Setting this field ensures bucket access is limited to AWS service principals and authorized users. Exclude this finding if this configuration is set at the account level
  bucket = "km-public-blob"
}

resource "aws_s3_bucket_public_access_block" "km_public_blob" {
  bucket = aws_s3_bucket.km_public_blob.id

  block_public_acls   = false
  block_public_policy = false
}