import json
import os
import semver
import sys

class Image:
    def __init__(self, name, description, version):
        self.name = name
        self.description = description
        self.version = version

        self.children = []
        self.parent = None
        self.current = {}

    def has_version(self):
        return self.version is not None and self.has_current()

    def has_current(self):
        return self.current != {}

    def has_parent(self):
        return self.parent is not None and self.parent.has_current()

    def add_child(self, image_obj):
        self.children.append(image_obj)

    def version_changed(self):
        return self.has_version() and self.version != self.current.get("ami_version")

    def ami_changed(self):
        return self.has_parent() and self.current.get("source_ami_id") != self.parent.current.get("ami_id")

    def has_changed(self):
        return self.ami_changed() or self.version_changed()


class Images:
    def __init__(self, current_images, defined_images):
        self.current_images = current_images
        self.defined_images = defined_images

        self.images = {}
        self.changed_images = {}
        self.packer = {}

    def _has_source_ami(self, definition):
        return definition.get("source_ami_name", "") != "" and definition.get("source_ami_name") in self.images

    def _propagate(self):
        self.images = {}
        for defined_image in self.defined_images:
            for image_definition in defined_image.get("images"):
                if image_definition.get("name") in self.images:
                    print("Duplicate declaration: {}".format(image_definition.get("name")))

                image = Image(image_definition.get("name"), image_definition.get("description"),
                              image_definition.get("version", None))
                current_image = self.current_images.get(image_definition.get("name"))
                if current_image:
                    image.current = current_image

                self.images.update({image_definition.get("name"): image})

        for defined_image in self.defined_images:
            for image_definition in defined_image.get("images"):
                leaf = self.images.get(image_definition.get("name"))
                if self._has_source_ami(image_definition):
                    parent = self.images.get(image_definition.get("source_ami_name"))
                    leaf.parent = parent
                    parent.add_child(leaf)

    def _propagate_changed(self):
        self.changed_images = {}
        images = list(self.images.values())
        image = images.pop()
        while image:
            if image.has_changed():
                while image.has_parent() and image.parent.has_changed():
                    image = image.parent

                self.changed_images.update({image.name: image})

            if len(images) > 0:
                image = images.pop()
            else:
                image = None

    def build_config(self):
        self.packer = {}

        self._propagate()
        self._propagate_changed()

        for defined_image in self.defined_images:
            overrides = {}
            shell_provisioners = []
            provisioners = []
            for provisioner_definition in defined_image.get("provisioners", []):
                if provisioner_definition.get("type") == "shell":
                    provisioner = dict({
                        "type": "shell",
                        "scripts": provisioner_definition.get("scripts"),
                    })
                    provisioners.append(provisioner)
                    shell_provisioners.append(provisioner)
                elif provisioner_definition.get("type") == "files":
                    for file_provisioner_definition in provisioner_definition.get("files"):
                        destination_file_name = os.path.basename(file_provisioner_definition.get("destination"))
                        provisioner = dict({
                          "type": "file",
                          "source": file_provisioner_definition.get("source"),
                          "destination": "/tmp/{}".format(destination_file_name)
                        })
                        provisioners.append(provisioner)
                        cmds = [
                            "sudo mv /tmp/{} {}".format(destination_file_name, file_provisioner_definition.get("destination"))
                        ]
                        if file_provisioner_definition.get("chown", False):
                            cmds.append("sudo chown {} {}".format(file_provisioner_definition.get("chown"), file_provisioner_definition.get("destination")))
                        if file_provisioner_definition.get("chmod", False):
                            cmds.append("sudo chmod {} {}".format(file_provisioner_definition.get("chmod"), file_provisioner_definition.get("destination")))
                        provisioner = dict({
                            "type": "shell",
                            "inline": cmds
                        })
                        provisioners.append(provisioner)

            packer = {
                "description": defined_image.get("name"),
                "provisioners": provisioners,
            }

            builders = []
            for image_definition in defined_image.get("images"):
                if image_definition.get("name") not in self.changed_images:
                    continue

                changed = self.changed_images.get(image_definition.get("name"))
                if changed.ami_changed() and not changed.version_changed():
                    changed.version = str(semver.parse_version_info(changed.version).bump_minor())

                builder = {
                    "type": "amazon-ebs",
                    "region": image_definition.get("region"),
                    "ssh_username": image_definition.get("source_ami_user"),
                    "instance_type": image_definition.get("instance_type"),
                    "iam_instance_profile": image_definition.get("iam_instance_profile"),
                    "run_tags": image_definition.get("run_tags"),
                    "tags": {},
                }

                # do not add aws profile while deploying from jenkins
                if not (os.environ.get('IS_DEPLOYMENT', 'false') == 'true'):
                    builder.update({"profile": image_definition.get("profile")})

                overrides.update({changed.name: {
                    "execute_command": "echo '{}' | sudo -S sh '{{{{.Path}}}}'".format(image_definition.get("source_ami_user"))
                }})

                builder.update({
                    "name": changed.name,
                    "source_ami": changed.parent.current.get("ami_id"),
                    "ami_name": '{}-{}'.format(changed.name, changed.version)
                })

                additional_regions = image_definition.get("additional_regions", [])

                tags = {
                   "Name": '{}-{}'.format(changed.name, changed.version),
                   "AmiVersion": changed.version,
                   "SourceAmiName": changed.parent.name,
                   "SourceAmiId": changed.parent.current.get("ami_id"),
                   "SshUsername": image_definition.get("source_ami_user"),
                   "BuildRegion": image_definition.get("region"),
                }
                if len(image_definition.get("additional_regions", [])) > 0:
                    tags.update({"AdditionalRegions": ",".join(image_definition.get("additional_regions"))})

                builder.get("tags", {}).update(tags)
                builder.update({
                    "snapshot_tags": tags,
                })

                builders.append(builder)

            if len(builders) > 0:
                for provisioner in shell_provisioners:
                    provisioner.update({"override": overrides})

                packer.update({"builders": builders})

                self.packer.update({defined_image.get("name"): json.dumps(packer)})


def read_in():
    return {x.strip() for x in sys.stdin}


lines = read_in()
input = {}
for line in lines:
    if line:
        input = json.loads(line)
        images = Images(json.loads(input["current_images"]), json.loads(input["image_definitions"]))
        images.build_config()
        sys.stdout.write(json.dumps(images.packer))


