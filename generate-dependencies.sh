#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nodePackages.node2nix

# cd "$(dirname $(readlink -f $0))"

# node2nix \
#   --node-env node-env.nix \
#   --input ./web/package.json \
#   --output node-packages.nix \
#   --composition node-composition.nix
#
  # --nodejs-16 \
  # --strip-optional-dependencies \
  #

node2nix \
  --development \
  --node-env ./node-env.nix \
  --output ./node-deps.nix \
  --input "./web/package.json" \
  --composition ./node-composition.nix
