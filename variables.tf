
variable "default_allowed_accounts" {
  type    = map(string)
  default = {}
}

variable "default_build_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "default_build_profile" {
  type = string
}

variable "images" {
  type        = any
  description = "A map of name => owner,searchstring image specifications"
}

variable "image_versions" {
  type        = map(string)
  description = "A map of image name => version"
}

variable "debug" {
  type        = bool
  description = "Whether to run in debug mode"
  default     = false
}

variable "packer_build" {
  type        = bool
  description = "Whether to run packer build (will be disabled if debug=true)"
  default     = true
}

variable "python_executeable" {
  default = ""
}

variable "build_region" {}
variable "build_profile" {}
variable "build_org_name" {}
variable "build_account_id" {}
variable "build_account_name" {}

locals {
  python = var.python_executeable == "" ? format("%s/.venv/bin/python", path.root) : var.python_executeable

  packer_build = var.debug ? false : var.packer_build

  images = flatten([
    for def in var.images : [
      for image_def in def["images"] : merge(
        image_def,
        {
          is_new           = lookup(var.image_versions, image_def["name"], "") == ""
          version          = lookup(var.image_versions, image_def["name"], "0.0.1")
          allowed_accounts = keys(length(lookup(image_def, "allowed_accounts", {})) > 0 ? image_def["allowed_accounts"] : length(lookup(def, "allowed_accounts", {})) > 0 ? def["allowed_accounts"] : var.default_allowed_accounts)
          group_name       = def["name"]
          run_tags = merge(
            {
              org         = var.build_org_name
              aws_account = var.build_account_name
              environment = terraform.workspace
            },
            lookup(image_def, "run_tags", {})
          )
          region               = lookup(image_def, "region", var.build_region),
          instance_type        = lookup(image_def, "instance_type", var.default_build_instance_type),
          iam_instance_profile = lookup(image_def, "iam_instance_profile", var.default_build_profile),
          profile              = lookup(image_def, "profile", var.build_profile),
        }
      )
    ]
  ])

  current = {
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

  packer_configs = {
    for key, value in data.external.image_configs.result : key => jsondecode(value)
  }

  has_changes = {
    for name, conf in local.current : name => conf["ami_version"] if conf["ami_version"] != ""
    } != merge(var.image_versions, {
      for conf in flatten([
        for k, conf in local.packer_configs : [
          for b in conf["builders"] : {
            name    = b["name"]
            version = b["tags"]["AmiVersion"]
          }
        ]
      ]) : conf["name"] => conf["version"]
  })

  latest = local.has_changes ? {
    for name, image in data.aws_ami.latest : name => {
      ami_name        = image.name
      ami_id          = image.id
      ami_version     = lookup(image.tags, "AmiVersion", "")
      source_ami_name = lookup(image.tags, "SourceAmiName", "")
      source_ami_id   = lookup(image.tags, "SourceAmiId", "")
      ssh_username    = lookup(image.tags, "SshUsername", "")
      build_region    = lookup(image.tags, "BuildRegion", "")
    }
  } : local.current

  image_definitions = flatten([
    for def in var.images : merge(
      def,
      { images = [for image in local.images : image if image["group_name"] == def["name"]] }
    )
  ])

  image_permission_definitions = {
    for def in local.images : def["name"] => def["allowed_accounts"]
  }

  image_permissions = toset(flatten([
    for image in data.aws_ami.all : formatlist("%s||%s", image["id"], lookup(local.image_permission_definitions, replace(image["name"], "/-\\d+\\.\\d+\\.\\d+/", ""), []))
  ]))
}
