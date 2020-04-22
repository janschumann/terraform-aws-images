data "aws_ami" "current" {
  for_each = {
    for image in local.images : image["name"] => lookup(image, "search_pattern", format("%s,%s*", var.build_account_id, image["name"])) if ! image["is_new"]
  }

  most_recent = true

  filter {
    name   = "name"
    values = [split(",", each.value)[1]]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = [split(",", each.value)[0]]
}

data "aws_ami" "latest" {
  for_each = local.has_changes ? {
    for image in local.images : image["name"] => lookup(image, "search_pattern", format("%s,%s*", var.build_account_id, image["name"]))
  } : {}

  most_recent = true

  filter {
    name   = "name"
    values = [split(",", each.value)[1]]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = [split(",", each.value)[0]]

  depends_on = [local_file.packer]
}

data "aws_ami_ids" "all" {
  filter {
    name   = "tag-key"
    values = ["Name"]
  }
  filter {
    name   = "tag-key"
    values = ["AmiVersion"]
  }
  filter {
    name   = "tag-key"
    values = ["SourceAmiName"]
  }
  filter {
    name   = "tag-key"
    values = ["SourceAmiId"]
  }
  filter {
    name   = "tag-key"
    values = ["SshUsername"]
  }
  filter {
    name   = "tag-key"
    values = ["BuildRegion"]
  }

  owners = ["self"]
}

data "aws_ami" "all" {
  for_each = toset(data.aws_ami_ids.all.ids)

  filter {
    name   = "image-id"
    values = [each.value]
  }

  owners = ["self"]
}

