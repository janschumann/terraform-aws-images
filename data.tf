data "aws_region" "current" {}

data "aws_ami" "current" {
  for_each = local.current_search_items

  filter {
    name   = "name"
    values = [each.value["search_pattern"]]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  most_recent = true
  owners      = [each.value["owner"]]
}

data "aws_ami" "latest" {
  for_each = local.latest_search_items

  filter {
    name   = "name"
    values = [each.value["search_pattern"]]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  most_recent = true
  owners      = [each.value["owner"]]

  depends_on = [local_file.packer]
}
