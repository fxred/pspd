Tem que instalar o rustup, o wasm-bindgen e colocar o wasm32-unknown-unknown como target e daí depois roda o rezzet

rustup target add wasm32-unknown-unknown
cargo install -f wasm-bindgen-cli