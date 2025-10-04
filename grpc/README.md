Passos:

1. Instalar as dependências Go e Ruby pra gRPC:
    `make setup`
    `make deps-all`
    E também baixar as gem's do ruby para http e tals
2. Gerar os proto's dos serviços A, B e P:
    `make proto`
    `make proto-ruby`
3. Executar o serviços
    `make run-all`