data "external" "packer_configs" {
  program = [var.python_executeable, format("%s/packerize.py", path.module)]

  query = {
    current_images    = jsonencode(local.current_amis)
    image_definitions = jsonencode(local.image_builder_config)
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
    command = ! var.debug ? format("%s build packer_%s.json && rm packer_%s.json", var.packer_executeable, each.key, each.key) : "echo build disabled"
  }
}

resource "local_file" "image_versions" {
  content = jsonencode({
    for name, conf in local.latest_amis : name => conf["ami_version"] if conf["ami_version"] != ""
  })
  filename = ".terraform/tmp_image_versions.json"

  # only write versions file if an ami has changed
  provisioner "local-exec" {
    command = local.has_changes ? "exit 0" : format("jq . .terraform/tmp_image_versions.json > %s", var.image_versions_path)
  }
}
