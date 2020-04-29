# AWS AMI image builder module

Terraform module which creates [Amazon Machine Images](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
on AWS with the help of [packer](https://packer.io)

## Prerequisites 

This module uses a few tools that need to be installed locally

* [python](https://python.org)
    * module [semver](https://pypi.org/project/semver/)
* [packer](https://packer.io)
* [jq](https://stedolan.github.io/jq/)

## Features

This module integrates packer with terraform by running packer a part of a local provisioner script.

The packer config format (json) does not support commenting, complex interpolation etc., so that maintaining, updating
and versioning packer builds can be a challenge. This module converts its own image configuration format (terraform 
variables) to packer templates. 

Currently only the [AMI Builder (EBS backed)](https://www.packer.io/docs/builders/amazon-ebs.html) is supported.

The config format used by this module is a list of image groups. Each image group uses the same set of provisioners  
(https://www.packer.io/docs/provisioners/index.html) to configure the images defined within that group, 
while currently only [file](https://www.packer.io/docs/provisioners/file.html) and 
[shell](https://www.packer.io/docs/provisioners/shell.html) provisioners are supported. Each image config uses the same 
parameters as the EBS builder, while credentials and AMI permissions are handled automatically and wont have to be set
for each individual image. 

While the list of image groups is a flat list, a hierarchy of dependent images is maintained using the `source_ami_name`
parameter on each image config. With the help of this parameter, a DAG is created, from which only branches with no 
interdependency will result in an image build. In other words: If an image `A` depends on image `B`, and image `B` 
needs to be upgraded, image `A` will not be considered to be built unless the dependent image reached its desired 
version.     

## Usage

```hcl
module "images" {
  source = "git@elbstack-git.de:qcx-ops/terraform-aws-images.git"

  default_allowed_accounts = [
    "1234567890",
    "0123456789"
  ]

  images              = [{
    name = "base"
    provisioners = [{
        type = "shell"
        scripts = [
          "./scripts/base.sh",
        ]
    }],
    images = [{
        name            = "my-aws-linux"
        description     = "my aws linux base image"
        source_ami_name = "aws-linux"
        source_ami_user = "ec2-user"
    }]
  }]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.12 |
| aws | ~> 2.7 |
| external | ~> 1.0 |
| local | ~> 1.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| builder\_credentials | The credentials to use to build the AMI | `map(string)` | `{}` | no |
| debug | Only create packer build files | `bool` | `false` | no |
| default\_allowed\_accounts | A list of account ids to allow images access to by default | `list(string)` | `[]` | no |
| default\_builder\_config | The default builder config. | `map(any)` | `{}` | no |
| image\_versions\_path | Path to a json file that contains the image versions as a map of strings. | `string` | `"./versions.json"` | no |
| images | A list of maps describing the images to build | `any` | n/a | yes |
| jq\_executeable | Path to the jq executable | `string` | `"/usr/bin/env jq"` | no |
| packer\_executeable | Path to the packer executable | `string` | `"/usr/bin/env packer"` | no |
| python\_executeable | Path to the python executable to execute the packerize script with. Make sure to install all requirements in requirements.txt | `string` | `"/usr/bin/env python"` | no |
| source\_images | A list of source images. By default the latest aws-linux image is referenced | <pre>list(object({<br>    name           = string,<br>    description    = string,<br>    owner          = string,<br>    search_pattern = string<br>  }))</pre> | <pre>[<br>  {<br>    "description": "aws linux 2",<br>    "name": "aws-linux",<br>    "owner": "137112412989",<br>    "search_pattern": "amzn2-ami-hvm-*-x86_64-ebs"<br>  }<br>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| latest | The list of the latest versions of the resulting amis |
| source\_images | The list of current source amis |

## Authors

Module managed by [Jan Schumann](https://github.com/janschumann).

## License

Apache 2 Licensed. See LICENSE for full details.
