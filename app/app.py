#!/usr/bin/env python3
import os
import sys
import json
import time
import logging
from datetime import datetime
from flask import Flask, render_template, jsonify, request
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import psutil
import threading

try:
    import GPUtil
    gpu_available = True
except ImportError:
    gpu_available = False
    GPUtil = None

try:
    from gpu_demos import GPUDemos
    gpu_demos_available = True
except ImportError:
    gpu_demos_available = False
    GPUDemos = None

app = Flask(__name__)
app.config['SECRET_KEY'] = 'gpu-demo-secret-key-2024'
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*")

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/gpu-demo/logs/app.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# Initialize GPU demos if available
gpu_demos = None
if gpu_demos_available:
    try:
        gpu_demos = GPUDemos()
        logger.info("GPU demos initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize GPU demos: {e}")
        gpu_demos_available = False

def get_system_info():
    """Get system information including GPU details"""
    try:
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        # Network info
        network = psutil.net_io_counters()
        
        system_info = {
            'timestamp': datetime.now().isoformat(),
            'cpu': {
                'usage_percent': cpu_percent,
                'count': psutil.cpu_count(),
                'freq': psutil.cpu_freq()._asdict() if psutil.cpu_freq() else None
            },
            'memory': {
                'total': memory.total,
                'available': memory.available,
                'used': memory.used,
                'percent': memory.percent
            },
            'disk': {
                'total': disk.total,
                'used': disk.used,
                'free': disk.free,
                'percent': (disk.used / disk.total) * 100
            },
            'network': {
                'bytes_sent': network.bytes_sent,
                'bytes_recv': network.bytes_recv,
                'packets_sent': network.packets_sent,
                'packets_recv': network.packets_recv
            }
        }
        
        # Add GPU info if available
        if gpu_available:
            try:
                gpus = GPUtil.getGPUs()
                gpu_info = []
                for gpu in gpus:
                    gpu_info.append({
                        'id': gpu.id,
                        'name': gpu.name,
                        'load': gpu.load * 100,
                        'memoryTotal': gpu.memoryTotal,
                        'memoryUsed': gpu.memoryUsed,
                        'memoryFree': gpu.memoryFree,
                        'temperature': gpu.temperature,
                        'uuid': gpu.uuid
                    })
                system_info['gpu'] = gpu_info
            except Exception as e:
                logger.warning(f"Error getting GPU info: {e}")
                system_info['gpu'] = []
        else:
            system_info['gpu'] = []
            
        return system_info
        
    except Exception as e:
        logger.error(f"Error getting system info: {e}")
        return {'error': str(e), 'timestamp': datetime.now().isoformat()}

def emit_system_stats():
    """Emit system stats via WebSocket"""
    while True:
        try:
            stats = get_system_info()
            socketio.emit('system_stats', stats)
            time.sleep(2)
        except Exception as e:
            logger.error(f"Error emitting system stats: {e}")
            time.sleep(5)

# Start background thread for system stats
stats_thread = threading.Thread(target=emit_system_stats)
stats_thread.daemon = True
stats_thread.start()

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('index.html', 
                         gpu_available=gpu_available,
                         gpu_demos_available=gpu_demos_available)

@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'gpu_available': gpu_available,
        'gpu_demos_available': gpu_demos_available
    })

@app.route('/api/system-info')
def system_info():
    """Get current system information"""
    return jsonify(get_system_info())

@app.route('/api/gpu-benchmark', methods=['POST'])
def gpu_benchmark():
    """Run GPU benchmark"""
    if not gpu_demos_available:
        return jsonify({'error': 'GPU demos not available'}), 400
    
    try:
        data = request.get_json()
        benchmark_type = data.get('type', 'matrix_multiply')
        size = data.get('size', 1024)
        
        if benchmark_type == 'matrix_multiply':
            result = gpu_demos.matrix_multiplication_benchmark(size)
        elif benchmark_type == 'image_processing':
            result = gpu_demos.image_processing_benchmark()
        elif benchmark_type == 'ml_inference':
            result = gpu_demos.ml_inference_benchmark()
        else:
            return jsonify({'error': 'Unknown benchmark type'}), 400
            
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"GPU benchmark error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/cpu-benchmark', methods=['POST'])
def cpu_benchmark():
    """Run CPU benchmark for comparison"""
    if not gpu_demos_available:
        return jsonify({'error': 'GPU demos not available'}), 400
    
    try:
        data = request.get_json()
        benchmark_type = data.get('type', 'matrix_multiply')
        size = data.get('size', 1024)
        
        if benchmark_type == 'matrix_multiply':
            result = gpu_demos.cpu_matrix_multiplication_benchmark(size)
        else:
            return jsonify({'error': 'CPU benchmark not available for this type'}), 400
            
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"CPU benchmark error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/gpu-info')
def gpu_info():
    """Get detailed GPU information"""
    if not gpu_available:
        return jsonify({'error': 'GPU not available'})
    
    try:
        gpus = GPUtil.getGPUs()
        gpu_list = []
        for gpu in gpus:
            gpu_list.append({
                'id': gpu.id,
                'name': gpu.name,
                'load': gpu.load,
                'memoryTotal': gpu.memoryTotal,
                'memoryUsed': gpu.memoryUsed,
                'memoryFree': gpu.memoryFree,
                'temperature': gpu.temperature,
                'uuid': gpu.uuid
            })
        return jsonify({'gpus': gpu_list})
    except Exception as e:
        logger.error(f"Error getting GPU info: {e}")
        return jsonify({'error': str(e)}), 500

@socketio.on('connect')
def handle_connect():
    """Handle WebSocket connection"""
    logger.info('Client connected')
    emit('connected', {'data': 'Connected to GPU Demo Server'})

@socketio.on('disconnect')
def handle_disconnect():
    """Handle WebSocket disconnection"""
    logger.info('Client disconnected')

@socketio.on('request_benchmark')
def handle_benchmark_request(data):
    """Handle benchmark request via WebSocket"""
    try:
        benchmark_type = data.get('type', 'matrix_multiply')
        size = data.get('size', 1024)
        
        if gpu_demos_available:
            if benchmark_type == 'matrix_multiply':
                gpu_result = gpu_demos.matrix_multiplication_benchmark(size)
                cpu_result = gpu_demos.cpu_matrix_multiplication_benchmark(size)
                
                emit('benchmark_result', {
                    'type': benchmark_type,
                    'gpu_result': gpu_result,
                    'cpu_result': cpu_result,
                    'speedup': cpu_result.get('time', 0) / gpu_result.get('time', 1)
                })
            else:
                emit('benchmark_error', {'error': 'Benchmark type not supported via WebSocket'})
        else:
            emit('benchmark_error', {'error': 'GPU demos not available'})
            
    except Exception as e:
        logger.error(f"WebSocket benchmark error: {e}")
        emit('benchmark_error', {'error': str(e)})

if __name__ == '__main__':
    logger.info("Starting GPU Demo Application...")
    logger.info(f"GPU Available: {gpu_available}")
    logger.info(f"GPU Demos Available: {gpu_demos_available}")
    
    # Run with socketio for WebSocket support
    socketio.run(app, 
                host='127.0.0.1', 
                port=5000, 
                debug=False,
                allow_unsafe_werkzeug=True)