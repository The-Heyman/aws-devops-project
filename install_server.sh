#!/bin/bash

sudo apt-get update -y
sudo apt-get install apache2 -y
sudo systemctl start apache2.service