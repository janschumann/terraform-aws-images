data "external" "image_configs" {
  program = [local.python, format("%s/resources/packerize.py", path.module)]

  query = {
    current_images    = jsonencode(local.current)
    image_definitions = jsonencode(local.image_definitions)
  }
}

resource "local_file" "packer" {
  for_each = local.packer_configs

  content  = jsonencode(each.value)
  filename = format(".terraform/packer_%s.json", each.key)

  provisioner "local-exec" {
    command = format("jq . .terraform/packer_%s.json > packer_%s.json", each.key, each.key)
  }

  provisioner "local-exec" {
    command = local.packer_build ? format("packer build packer_%s.json && rm packer_%s.json", each.key, each.key) : "echo build disabled"
  }
}

resource "aws_ami_launch_permission" "permissions" {
  for_each   = local.image_permissions
  account_id = split("||", each.value)[1]
  image_id   = split("||", each.value)[0]
}
