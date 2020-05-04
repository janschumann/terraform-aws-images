locals {
  # if no credentials are provided, set the current region
  builder_credentials = merge(
    {
      region = data.aws_region.current.name
    },
    var.builder_credentials
  )

  # fetch current image versions
  image_versions = jsondecode(file(var.image_versions_path))

  # create a default image builder config by merging in the credentials
  default_builder_config = merge({
    name                 = ""
    description          = ""
    allowed_accounts     = []
    run_tags             = {}
    tags                 = {}
    instance_type        = "t3.medium"
    iam_instance_profile = ""
    owner                = "self"
    search_pattern       = ""
    source_ami_name      = ""
    source_ami_user      = ""
  }, var.default_builder_config, local.builder_credentials)

  # create a list of image configurations including the source images
  images = concat(
    # add the source images
    [
      for image_def in var.source_images : merge(
        local.default_builder_config,
        image_def,
        {
          # we do not maintain version numbers for aws images
          version        = "n/a"
          group_name     = "aws_source_images"
          owner          = image_def["owner"]
          search_pattern = image_def["search_pattern"]
        }
      )
    ],
    # add the image definitions
    flatten([
      for def in var.images : [
        for image_def in def["images"] : merge(
          local.default_builder_config,
          image_def,
          {
            version    = lookup(local.image_versions, image_def["name"], "0.0.0")
            group_name = def["name"]
            run_tags = merge(
              {
                environment = terraform.workspace
              },
              local.default_builder_config["run_tags"],
              lookup(image_def, "run_tags", {})
            )
            tags = merge(
              local.default_builder_config["tags"],
              lookup(image_def, "tags", {})
            )
            search_pattern = format("%s-*", image_def["name"])
          },
          {
            allowed_accounts = length(lookup(image_def, "allowed_accounts", [])) > 0 ? image_def["allowed_accounts"] : length(lookup(def, "allowed_accounts", [])) > 0 ? def["allowed_accounts"] : var.default_allowed_accounts
          }
        )
      ]
    ])
  )

  # create the complete builder config by replacing each image config with the merged version
  image_builder_config = concat(
    flatten([
      for def in var.images : merge(
        def,
        {
          images = [for image in local.images : image if image["group_name"] == def["name"]]
        }
      )
    ]),
    flatten([
      for def in var.source_images : merge(
        def,
        {
          images = [for image in local.images : image if image["group_name"] == "aws_source_images"]
        }
      )
    ])
  )
  # current data source should only search for images that we maintain
  current_search_items = {
    for image in local.images : image["name"] => image if image["version"] != "0.0.0"
  }

  # a list of current ami resources
  current_amis = {
    for name, image in data.aws_ami.current : name => {
      ami_name        = image.name
      ami_id          = image.id
      ami_version     = lookup(image.tags, "AmiVersion", "")
      source_ami_name = lookup(image.tags, "SourceAmiName", "")
      source_ami_id   = lookup(image.tags, "SourceAmiId", "")
      ssh_username    = lookup(image.tags, "SshUsername", "")
      build_region    = lookup(image.tags, "BuildRegion", "")
    }
  }

  # read the final packer builder configs from packerize script
  packer_configs = {
    for key, value in data.external.packer_configs.result : key => jsondecode(value)
  }

  # are versions found in aws are the same as the final builder configurations?
  has_changes = var.debug ? false : {
    for name, image in local.current_amis : name => image["ami_version"] if image["ami_version"] != ""
    } != merge(local.image_versions, {
      for image in flatten([
        for k, conf in local.packer_configs : [
          for b in conf["builders"] : {
            name    = b["name"]
            version = b["tags"]["AmiVersion"]
          }
        ]
      ]) : image["name"] => image["version"]
  })

  # latest data source should only search for images if something has changed
  latest_search_items = local.has_changes ? {
    for image in local.images : image["name"] => image
  } : {}

  # if there are no changes, just return the current ami list
  latest_amis = local.has_changes ? {
    for name, image in data.aws_ami.latest : name => {
      ami_name        = image.name
      ami_id          = image.id
      ami_version     = lookup(image.tags, "AmiVersion", "")
      source_ami_name = lookup(image.tags, "SourceAmiName", "")
      source_ami_id   = lookup(image.tags, "SourceAmiId", "")
      ssh_username    = lookup(image.tags, "SshUsername", "")
      build_region    = lookup(image.tags, "BuildRegion", "")
    }
  } : local.current_amis
}
