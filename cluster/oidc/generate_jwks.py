import json
from base64 import urlsafe_b64encode
from cryptography.hazmat.primitives import serialization

with open('/keys/sa.pub', 'rb') as key_file:
    public_key = serialization.load_pem_public_key(key_file.read())

numbers = public_key.public_numbers()
e = numbers.e.to_bytes((numbers.e.bit_length() + 7) // 8, byteorder='big')
n = numbers.n.to_bytes((numbers.n.bit_length() + 7) // 8, byteorder='big')

jwks = {
    "keys": [
        {
            "kty": "RSA",
            "alg": "RS256",
            "use": "sig",
            "kid": "1",
            "n": urlsafe_b64encode(n).decode('utf-8').rstrip('='),
            "e": urlsafe_b64encode(e).decode('utf-8').rstrip('='),
        }
    ]
}

with open('/oidc/openid/v1/jwks', 'w') as f:
    json.dump(jwks, f)