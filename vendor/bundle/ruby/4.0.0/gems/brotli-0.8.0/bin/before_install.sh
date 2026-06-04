#!/bin/bash
set -ev
gem update --system || gem update --system '2.7.8'
if [ "$(gem --version | cut -b 1)" = 3 ]; then
  echo "gem: -N" >> ~/.gemrc
else
  echo "gem: --no-ri --no-rdoc" >> ~/.gemrc
fi
gem install bundler || gem install bundler -v '< 2'
