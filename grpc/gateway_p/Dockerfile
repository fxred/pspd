FROM ruby:3.2-slim

WORKDIR /app

# 1. Instalar ferramentas de compilação
# Necessário para as gems nativas como bigdecimal e gRPC
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    zlib1g-dev \
    # Limpa o cache
    && rm -rf /var/lib/apt/lists/*

# 2. Instalar gems
# Copia o Gemfile (e assume que o Gemfile.lock não é usado/está ausente)
COPY gateway_p/Gemfile ./
RUN bundle install --without development test

# -------------------------------------------------------------
# CORREÇÃO CRÍTICA: COPIAR ARQUIVOS DE CONTRATO JÁ GERADOS
# O Ruby espera 'lib' no LOAD_PATH. Copiamos a pasta 'lib'
# que contém os arquivos _pb.rb e _services_pb.rb.
# -------------------------------------------------------------
# Copia a pasta lib/ (com os arquivos _pb.rb e _services_pb.rb gerados)
COPY gateway_p/lib ./lib 

# 3. Copia o código principal do Gateway
COPY gateway_p/gateway_p_ruby.rb .
COPY gateway_p/config.ru .

EXPOSE 8082

# Comando para iniciar o serviço Ruby (porta 8082)
CMD ["rackup", "--host", "0.0.0.0", "-p", "8082"]