"""Small local Flask API for the heart-disease student prototype."""
import os
from flask import Flask, Response, jsonify, request
from flask_cors import CORS
from werkzeug.exceptions import HTTPException
from research.prediction import HeartService


def create_app(service=None):
    app = Flask(__name__)
    app.config['MAX_CONTENT_LENGTH'] = 64 * 1024
    CORS(app, origins=os.environ.get('CORS_ORIGINS', 'http://localhost:8080').split(','))
    service = service or HeartService()

    @app.errorhandler(Exception)
    def error(exc):
        if isinstance(exc, FileNotFoundError):
            return jsonify(error=str(exc)), 503
        if isinstance(exc, (ValueError, TypeError, UnicodeError)):
            return jsonify(error=str(exc)), 400
        if isinstance(exc, HTTPException):
            return jsonify(error=exc.description), exc.code
        app.logger.exception('Assessment failed')
        return jsonify(error='The assessment could not finish. Please try again.'), 500

    def body():
        value = request.get_json()
        if not isinstance(value, dict):
            raise ValueError('Please send a JSON object')
        return value

    @app.get('/health')
    def health():
        return jsonify(status='ok', mode='heart-research-prototype')

    @app.get('/api/config')
    def config():
        metadata = service.load()['metadata']
        return jsonify(features=metadata['features'], model_version=metadata['version'], comparison=metadata['comparison'])

    @app.get('/api/sample')
    def sample():
        bundle = service.load()
        return jsonify(features=bundle['sample'], source='UCI Cleveland benchmark', partition='held-out test', row=bundle['sample_row'])

    @app.get('/api/template')
    def template():
        return Response(service.template(), mimetype='text/csv', headers={'Content-Disposition': 'attachment; filename=heart-assessment-template.csv'})

    @app.post('/api/import')
    def import_csv():
        data = body()
        if not isinstance(data.get('csv'), str):
            raise ValueError('Choose a CSV file using the supplied template')
        return jsonify(features=service.import_csv(data['csv']))

    @app.post('/api/analyze')
    def analyze():
        return jsonify(service.analyze(body().get('features')))

    @app.route('/predict', methods=['POST'])
    @app.route('/history', methods=['GET'])
    def legacy():
        return jsonify(error='This older synthetic-risk route is retired. Use the heart assessment app.'), 410

    return app


app = create_app()
if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, debug=False)
