import os
from flask import Flask, request, jsonify
import yt_dlp
from flask_cors import CORS

app = Flask(__name__)
CORS(app) 

@app.route('/api/extract', methods=['GET'])
def extract_video_info():
    video_url = request.args.get('url')
    if not video_url:
        return jsonify({'error': 'No URL provided'}), 400

    ydl_opts = {
        'format': 'best',
        'quiet': True,
        'no_warnings': True,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(video_url, download=False)
            
            return jsonify({
                'title': info.get('title', 'Downloaded_Video'),
                'direct_url': info.get('url'),
                'ext': info.get('ext', 'mp4'),
                'extractor': info.get('extractor_key', 'Unknown')
            })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # Cloud servers assign a random port. This tells Python to listen to it.
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)
