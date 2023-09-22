docker run --rm --entrypoint cat my_package:latest /requirements.deploy.bin | \
    openssl enc -d -in - -aes-256-cbc -pbkdf2 -out requirements.deploy.txt -pass pass:SomePassword
