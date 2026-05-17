#!/usr/bin/env bash 
ansible-playbook -i ./hosts.yml ./impsy.yml --ask-pass --ask-become-pass --skip-tags prep-image
