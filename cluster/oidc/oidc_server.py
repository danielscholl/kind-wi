from flask import Flask, send_from_directory
app = Flask(__name__)

@app.route('/.well-known/openid-configuration')
def openid_configuration():
    return send_from_directory('/oidc/.well-known', 'openid-configuration', mimetype='application/json')

@app.route('/openid/v1/jwks')
def jwks():
    return send_from_directory('/oidc/openid/v1', 'jwks', mimetype='application/json')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)