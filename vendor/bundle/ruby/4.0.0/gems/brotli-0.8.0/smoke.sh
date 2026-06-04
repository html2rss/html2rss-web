#!/bin/bash
gem list | grep brotli && gem uninstall --force brotli
bundle exec rake clobber build
gem install --force --local "$(ls pkg/brotli-*.gem)"
cat <<EOF | ruby
require 'brotli'
abort if Brotli.inflate(Brotli.deflate(File.read('smoke.sh'))) != File.read('smoke.sh')
EOF
