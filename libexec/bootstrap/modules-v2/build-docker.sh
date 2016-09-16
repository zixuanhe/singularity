#!/bin/bash
# 
# Copyright (c) 2015-2016, Gregory M. Kurtzer. All rights reserved.
# 
# “Singularity” Copyright (c) 2016, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
# 
# This software is licensed under a customized 3-clause BSD license.  Please
# consult LICENSE file distributed with the sources of this project regarding
# your rights to use or distribute this software.
# 
# NOTICE.  This Software was developed under funding from the U.S. Department of
# Energy and the U.S. Government consequently retains certain rights. As such,
# the U.S. Government has been granted for itself and others acting on its
# behalf a paid-up, nonexclusive, irrevocable, worldwide license in the Software
# to reproduce, distribute copies to the public, prepare derivative works, and
# perform publicly and display publicly, and to permit other to do so. 
# 
# 

## Basic sanity
if [ -z "$SINGULARITY_libexecdir" ]; then
    echo "Could not identify the Singularity libexecdir."
    exit 1
fi

# Ensure the user has provided a docker image name with "From"
if [ -z "$SINGULARITY_DOCKER_IMAGE" ]; then
    echo "Please specify the Docker image name with From: in the definition file."
    exit 1
fi

## Load functions
if [ -f "$SINGULARITY_libexecdir/singularity/functions" ]; then
    . "$SINGULARITY_libexecdir/singularity/functions"
else
    echo "Error loading functions: $SINGULARITY_libexecdir/singularity/functions"
    exit 1
fi

if [ -z "${SINGULARITY_ROOTFS:-}" ]; then
    message ERROR "Singularity root file system not defined\n"
    exit 1
fi

if [ -z "${SINGULARITY_BUILDDEF:-}" ]; then
    message ERROR "Singularity build definition file not defined\n"
    exit 1
fi


########## BEGIN BOOTSTRAP SCRIPT ##########

# Split the docker image name by :
IFS=':' read -ra DOCKER_ADDR <<< "$SINGULARITY_DOCKER_IMAGE"

# If there are two parts, we have image and tag
if [ ${#DOCKER_ADDR[@]} -eq 2 ]; then
    repo_name=${DOCKER_ADDR[0]}
    repo_tag=${DOCKER_ADDR[1]}

# Otherwise, assume latest of an image
else
    repo_name=${DOCKER_ADDR[0]}
    #TODO: we need to get latest tag with API
    repo_tag="latest"
fi

# Obtain the image manifest
/v2/<name>/manifests/<reference>
manifest=$(curl -k https://registry.hub.docker.com/v1/library/ubuntu:latest/manifests)

# First obtain the list of image tags
image_tags=$(curl -k https://registry.hub.docker.com/v1/repositories/$repo_name/tags)
image_tags=$(echo $image_tags | grep -Po '"name": "(.*?)"')


# This will only match a tag directly, eg, 14.04.1 must be given and not 14.04
found_tag=$(echo $image_tags | grep -Po '"name": "(.*?)"' | while read a; do 

    # remove "name": and extra "'s
    contender_tag=`echo ${a/\"name\":/}`
    contender_tag=`echo ${contender_tag//\"/}`

    # Does the tag equal our specified repo tag?
    if [ $contender_tag == $repo_tag ]; then
       echo $contender_tag
    fi
done)

# Did we find a tag?
if [ -z "$found_tag" ]; then
    message ERROR "Docker tag $repo_name:$repo_tag not found with Docker Registry API v.1.0\n"
    exit 1
fi

# STOPPED HERE... work in progress
# If we have a repo name and a tag, continue!
token=$(curl -si https://registry.hub.docker.com/v1/repositories/library/ubuntu/images -H 'X-Docker-Token: true' | grep X-Docker-Token)

curl https://cdn-registry-1.docker.io/v1/images/511136ea3c5a64f264b78b5433614aec563103b4d4702f3ba7d4d2698e22c158/json -H $token

'Authorization: Token signature=01b8e3d3ef56515b33d9f68824134e3460de3a1a,repository="library/ubuntu",access=read'

{"id":"511136ea3c5a64f264b78b5433614aec563103b4d4702f3ba7d4d2698e22c158","comment":"Imported from -","created":"2013-06-13T14:03:50.821769-07:00","container_config":{"Hostname":"","User":"","Memory":0,"MemorySwap":0,"CpuShares":0,"AttachStdin":false,"AttachStdout":false,"AttachStderr":false,"PortSpecs":null,"Tty":false,"OpenStdin":false,"StdinOnce":false,"Env":null,"Cmd":null,"Dns":null,"Image":"","Volumes":null,"VolumesFrom":""},"docker_version":"0.4.0","architecture":"x86_64"}

List library repository images
GET /v1/repositories/(repo_name)/images

Get the images for a library repo.

Example Request:

    GET /v1/repositories/foobar/images HTTP/1.1
    Host: index.docker.io
    Accept: application/json
Parameters:

repo_name – the library name for the repo



# Get token for the Hub API

MIRROR=`singularity_key_get "MirrorURL" "$SINGULARITY_BUILDDEF"`
if [ -z "${MIRROR:-}" ]; then
    MIRROR="https://www.busybox.net/downloads/binaries/busybox-x86_64"
fi


mkdir -p -m 0755 "$SINGULARITY_ROOTFS/bin"
mkdir -p -m 0755 "$SINGULARITY_ROOTFS/etc"

echo "root:!:0:0:root:/root:/bin/sh" > "$SINGULARITY_ROOTFS/etc/passwd"
echo " root:x:0:" > "$SINGULARITY_ROOTFS/etc/group"
echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" > "$SINGULARITY_ROOTFS/etc/hosts"

curl "$MIRROR" > "$SINGULARITY_ROOTFS/bin/busybox"

chmod 0755 "$SINGULARITY_ROOTFS/bin/busybox"

eval "$SINGULARITY_ROOTFS/bin/busybox" --install "$SINGULARITY_ROOTFS/bin/"


# If we got here, exit...
exit 0
