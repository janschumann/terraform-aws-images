output "source_images" {
  description = "The list of current source amis"
  value = {
    for name, conf in local.latest_amis : name => {
      ami_id   = conf["ami_id"]
      ami_name = conf["ami_name"]
    } if conf["ami_version"] == ""
  }
}

output "latest" {
  description = "The list of the latest versions of the resulting amis"
  value = {
    for name, conf in local.latest_amis : name => conf if conf["ami_version"] != ""
  }
}
