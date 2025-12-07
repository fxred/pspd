<!-- Instalar o locust -->
pip install locust 

<!-- Entrar na pasta grpc -->
cd grpc

<!-- Exuctar o locust, na flag --host deve ser endereço de onde o gateway está sendo executado -->
python -m locust -f ./testes/locustfile.py --host=http://localhost:8082