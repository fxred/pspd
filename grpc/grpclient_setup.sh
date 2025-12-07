#!/bin/bash
set -e

rm -rf wasm_game_client/www/pkg

cargo build --target wasm32-unknown-unknown --release --package wasm_game_client

wasm-bindgen target/wasm32-unknown-unknown/release/wasm_game_client.wasm \
  --out-dir wasm_game_client/www/pkg \
  --target web

cd wasm_game_client/www

python3 -m http.server 8080