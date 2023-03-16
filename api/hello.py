from flask import Flask
from fabric.operations import local
app = Flask(__name__)

@app.route("/")
def hello():
    result = local('ip route | sed -e "s/ via.*//g" -e "s/ dev.*//g"', capture=True).split(' ')
    return('\n'.join(result))

app.run(host='0.0.0.0')
