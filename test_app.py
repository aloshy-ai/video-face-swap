from flask import Flask, jsonify

# Initialize Flask app
app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "healthy"})

@app.route('/', methods=['GET'])
def home():
    """Home page"""
    return jsonify({
        "message": "Video Face Swap API Test Server",
        "status": "running",
        "endpoints": [
            "/health",
            "/swap (not implemented in test version)"
        ]
    })

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=8080)
