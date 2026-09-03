variable "name" { type = string }

resource "random_string" "suffix" { length = 8 upper = false special = false }
locals { evidence_name = "${var.name}-evidence-${random_string.suffix.result}" audit_name = "${var.name}-audit-${random_string.suffix.result}" }
resource "aws_s3_bucket" "evidence" { bucket = local.evidence_name }
resource "aws_s3_bucket_public_access_block" "evidence" { bucket = aws_s3_bucket.evidence.id block_public_acls = true block_public_policy = true ignore_public_acls = true restrict_public_buckets = true }
resource "aws_s3_bucket_versioning" "evidence" { bucket = aws_s3_bucket.evidence.id versioning_configuration { status = "Enabled" } }
resource "aws_s3_bucket_server_side_encryption_configuration" "evidence" { bucket = aws_s3_bucket.evidence.id rule { apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" } } }
resource "aws_s3_bucket_lifecycle_configuration" "evidence" { bucket = aws_s3_bucket.evidence.id rule { id = "expire-demo-evidence" status = "Enabled" expiration { days = 30 } noncurrent_version_expiration { noncurrent_days = 7 } } }
resource "aws_s3_bucket" "audit" { bucket = local.audit_name }
resource "aws_s3_bucket_public_access_block" "audit" { bucket = aws_s3_bucket.audit.id block_public_acls = true block_public_policy = true ignore_public_acls = true restrict_public_buckets = true }
resource "aws_s3_bucket_versioning" "audit" { bucket = aws_s3_bucket.audit.id versioning_configuration { status = "Enabled" } }
resource "aws_s3_bucket_server_side_encryption_configuration" "audit" { bucket = aws_s3_bucket.audit.id rule { apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" } } }
data "aws_iam_policy_document" "cloudtrail" { statement { principals { type = "Service" identifiers = ["cloudtrail.amazonaws.com"] } actions = ["s3:GetBucketAcl"] resources = [aws_s3_bucket.audit.arn] } statement { principals { type = "Service" identifiers = ["cloudtrail.amazonaws.com"] } actions = ["s3:PutObject"] resources = ["${aws_s3_bucket.audit.arn}/AWSLogs/*"] condition { test = "StringEquals" variable = "s3:x-amz-acl" values = ["bucket-owner-full-control"] } } }
resource "aws_s3_bucket_policy" "audit" { bucket = aws_s3_bucket.audit.id policy = data.aws_iam_policy_document.cloudtrail.json }
resource "aws_cloudtrail" "this" { name = "${var.name}-trail" s3_bucket_name = aws_s3_bucket.audit.id is_multi_region_trail = false enable_logging = true depends_on = [aws_s3_bucket_policy.audit] }
output "evidence_bucket_name" { value = aws_s3_bucket.evidence.bucket }
