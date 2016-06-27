#!/bin/bash
set -e  # Halt on error
set -vx # Echo each line and each variable

if [ "$#" -ne 1 ]; then
    echo "USAGE: $0 NAME"
    exit 1
fi

NAME=$1
OV_TMP=/tmp/ov-deploy-tools-`date '+%Y-%m-%d_%H-%M-%S'`

mkdir $OV_TMP
cd $OV_TMP

git clone https://github.com/WGBH/aws-wrapper.git
git clone https://github.com/WGBH/mla-playbooks.git
git clone https://github.com/WGBH/openvault3_deploy.git

source ~/.rvm/scripts/rvm
# In non-iteractive mode, RVM binary is available, but 'cd' doesn't trigger the fuction.
# This should fix that.

# 1. AWS

cd aws-wrapper
cp scripts/defaults.template.yml scripts/defaults.yml
ruby scripts/build.rb --name $NAME.wgbh-mla-test.org

# 2. Ansible

echo '[webservers]' > ../mla-playbooks/openvault/hosts
ruby scripts/ssh_opt.rb --name $NAME.wgbh-mla-test.org --just_ips >> ../mla-playbooks/openvault/hosts
cd ../mla-playbooks # Error without this: "the role 'gcc' was not found"
ansible-playbook -i openvault/hosts openvault/site.yml --private-key ~/.ssh/$NAME.wgbh-mla-test.org.pem

# 3. Capistrano

cd ../openvault3_deploy

# TODO: Right now capistrano binds a name to an IP in config, which won't work for us going forward.

# So, for right now follow the instructions by hand.

# 4. Index

# Indexing on each machine separately is processor inefficient, but
# - it is simpler
# - and if done in parallel, no slower.

# TODO
