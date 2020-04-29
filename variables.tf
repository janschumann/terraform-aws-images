variable "builder_credentials" {
  type        = map(string)
  description = "The credentials to use to build the AMI"
  default     = {}
}

variable "images" {
  type        = any
  description = "A list of maps describing the images to build"
}

variable "source_images" {
  type = list(object({
    name           = string,
    description    = string,
    owner          = string,
    search_pattern = string
  }))
  description = "A list of source images. By default the latest aws-linux image is referenced"
  default = [
    {
      name           = "aws-linux"
      description    = "aws linux 2"
      owner          = "137112412989"
      search_pattern = "amzn2-ami-hvm-*-x86_64-ebs"
    }
  ]
}

variable "image_versions_path" {
  type        = string
  description = "Path to a json file that contains the image versions as a map of strings."
  default     = "./versions.json"
}

variable "default_builder_config" {
  type        = map(any)
  description = "The default builder config."
  default     = {}
}

variable "default_allowed_accounts" {
  type        = list(string)
  description = "A list of account ids to allow images access to by default"
  default     = []
}

variable "debug" {
  type        = bool
  description = "Only create packer build files"
  default     = false
}

variable "python_executeable" {
  type        = string
  description = "Path to the python executable to execute the packerize script with. Make sure to install all requirements in requirements.txt"
  default     = "/usr/bin/env python"
}

variable "packer_executeable" {
  type        = string
  description = "Path to the packer executable"
  default     = "/usr/bin/env packer"
}

variable "jq_executeable" {
  type        = string
  description = "Path to the jq executable"
  default     = "/usr/bin/env jq"
}
