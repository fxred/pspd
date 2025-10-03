rm -rf ./target
rm -rf ./www/pkg

cargo build --target wasm32-unknown-unknown --release
wasm-bindgen --out-dir www/pkg --target web target/wasm32-unknown-unknown/release/wasm_game_client.wasm

cd www
python3 -m http.server 8080
