// GPU Performance Demo JavaScript

class GPUDemoApp {
    constructor() {
        this.socket = null;
        this.charts = {};
        this.systemData = {
            cpu: [],
            memory: [],
            gpu: [],
            network: { sent: [], received: [] }
        };
        this.maxDataPoints = 30;
        this.isConnected = false;
        
        this.init();
    }
    
    init() {
        this.initSocketIO();
        this.initCharts();
        this.initEventListeners();
        this.loadSystemInfo();
        this.loadGPUInfo();
    }
    
    initSocketIO() {
        this.socket = io();
        
        this.socket.on('connect', () => {
            console.log('Connected to server');
            this.isConnected = true;
            this.updateConnectionStatus(true);
        });
        
        this.socket.on('disconnect', () => {
            console.log('Disconnected from server');
            this.isConnected = false;
            this.updateConnectionStatus(false);
        });
        
        this.socket.on('system_stats', (data) => {
            this.updateSystemStats(data);
        });
        
        this.socket.on('benchmark_result', (data) => {
            this.displayBenchmarkResult(data);
            this.hideLoadingModal();
        });
        
        this.socket.on('benchmark_error', (data) => {
            this.showError('Benchmark Error', data.error);
            this.hideLoadingModal();
        });
    }
    
    updateConnectionStatus(connected) {
        const statusElement = document.getElementById('connection-status');
        if (connected) {
            statusElement.textContent = 'Connected';
            statusElement.className = 'badge bg-success status-connected';
        } else {
            statusElement.textContent = 'Disconnected';
            statusElement.className = 'badge bg-danger status-disconnected';
        }
    }
    
    initCharts() {
        // CPU Usage Chart
        this.charts.cpu = new Chart(document.getElementById('cpuChart'), {
            type: 'line',
            data: {
                labels: Array(this.maxDataPoints).fill(''),
                datasets: [{
                    label: 'CPU Usage (%)',
                    data: Array(this.maxDataPoints).fill(0),
                    borderColor: '#667eea',
                    backgroundColor: 'rgba(102, 126, 234, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: this.getChartOptions('CPU Usage (%)', 0, 100)
        });
        
        // Memory Usage Chart
        this.charts.memory = new Chart(document.getElementById('memoryChart'), {
            type: 'line',
            data: {
                labels: Array(this.maxDataPoints).fill(''),
                datasets: [{
                    label: 'Memory Usage (%)',
                    data: Array(this.maxDataPoints).fill(0),
                    borderColor: '#f5576c',
                    backgroundColor: 'rgba(245, 87, 108, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: this.getChartOptions('Memory Usage (%)', 0, 100)
        });
        
        // GPU Usage Chart
        this.charts.gpu = new Chart(document.getElementById('gpuChart'), {
            type: 'line',
            data: {
                labels: Array(this.maxDataPoints).fill(''),
                datasets: [{
                    label: 'GPU Usage (%)',
                    data: Array(this.maxDataPoints).fill(0),
                    borderColor: '#56ab2f',
                    backgroundColor: 'rgba(86, 171, 47, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: this.getChartOptions('GPU Usage (%)', 0, 100)
        });
        
        // Network Chart
        this.charts.network = new Chart(document.getElementById('networkChart'), {
            type: 'line',
            data: {
                labels: Array(this.maxDataPoints).fill(''),
                datasets: [
                    {
                        label: 'Network In (KB/s)',
                        data: Array(this.maxDataPoints).fill(0),
                        borderColor: '#764ba2',
                        backgroundColor: 'rgba(118, 75, 162, 0.1)',
                        fill: false,
                        tension: 0.4
                    },
                    {
                        label: 'Network Out (KB/s)',
                        data: Array(this.maxDataPoints).fill(0),
                        borderColor: '#f093fb',
                        backgroundColor: 'rgba(240, 147, 251, 0.1)',
                        fill: false,
                        tension: 0.4
                    }
                ]
            },
            options: this.getChartOptions('Network (KB/s)', 0, null)
        });
    }
    
    getChartOptions(title, min, max) {
        return {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                title: {
                    display: true,
                    text: title,
                    font: { weight: 'bold' }
                },
                legend: {
                    display: false
                }
            },
            scales: {
                x: {
                    display: false
                },
                y: {
                    beginAtZero: true,
                    min: min,
                    max: max
                }
            },
            elements: {
                point: {
                    radius: 0
                }
            },
            interaction: {
                intersect: false
            }
        };
    }
    
    initEventListeners() {
        // Matrix Multiplication Benchmark
        document.getElementById('runMatrixBenchmark')?.addEventListener('click', () => {
            const size = document.getElementById('matrixSize').value;
            this.runBenchmark('matrix_multiply', { size: parseInt(size) });
        });
        
        // ML Benchmark
        document.getElementById('runMLBenchmark')?.addEventListener('click', () => {
            const algorithm = document.getElementById('mlAlgorithm').value;
            if (algorithm === 'kmeans') {
                this.runAPIBenchmark('/api/gpu-benchmark', 'ml_inference');
            } else if (algorithm === 'linear_regression') {
                this.runAPIBenchmark('/api/gpu-benchmark', 'linear_regression');
            }
        });
        
        // Image Processing Benchmark
        document.getElementById('runImageBenchmark')?.addEventListener('click', () => {
            this.runAPIBenchmark('/api/gpu-benchmark', 'image_processing');
        });
    }
    
    runBenchmark(type, params = {}) {
        this.showLoadingModal(`Running ${type} benchmark...`);
        this.socket.emit('request_benchmark', { type, ...params });
    }
    
    runAPIBenchmark(endpoint, benchmarkType) {
        this.showLoadingModal(`Running ${benchmarkType} benchmark...`);
        
        fetch(endpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ type: benchmarkType })
        })
        .then(response => response.json())
        .then(data => {
            if (data.error) {
                this.showError('Benchmark Error', data.error);
            } else {
                this.displaySingleBenchmarkResult(data, benchmarkType);
            }
            this.hideLoadingModal();
        })
        .catch(error => {
            this.showError('Network Error', error.message);
            this.hideLoadingModal();
        });
    }
    
    showLoadingModal(text) {
        document.getElementById('loadingText').textContent = text;
        const modal = new bootstrap.Modal(document.getElementById('loadingModal'));
        modal.show();
    }
    
    hideLoadingModal() {
        const modal = bootstrap.Modal.getInstance(document.getElementById('loadingModal'));
        if (modal) {
            modal.hide();
        }
    }
    
    loadSystemInfo() {
        fetch('/api/system-info')
            .then(response => response.json())
            .then(data => {
                this.displaySystemInfo(data);
            })
            .catch(error => {
                console.error('Error loading system info:', error);
                document.getElementById('system-info').innerHTML = 
                    '<div class="alert alert-danger">Failed to load system information</div>';
            });
    }
    
    loadGPUInfo() {
        fetch('/api/gpu-info')
            .then(response => response.json())
            .then(data => {
                this.displayGPUInfo(data);
            })
            .catch(error => {
                console.error('Error loading GPU info:', error);
                document.getElementById('gpu-info').innerHTML = 
                    '<div class="alert alert-warning">GPU information not available</div>';
            });
    }
    
    displaySystemInfo(data) {
        if (data.error) {
            document.getElementById('system-info').innerHTML = 
                `<div class="alert alert-danger">${data.error}</div>`;
            return;
        }
        
        const html = `
            <div class="metric-card">
                <div class="metric-value">${data.cpu?.usage_percent?.toFixed(1) || 'N/A'}%</div>
                <div class="metric-label">CPU Usage</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${data.memory?.percent?.toFixed(1) || 'N/A'}%</div>
                <div class="metric-label">Memory Usage</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${data.disk?.percent?.toFixed(1) || 'N/A'}%</div>
                <div class="metric-label">Disk Usage</div>
            </div>
        `;
        
        document.getElementById('system-info').innerHTML = html;
    }
    
    displayGPUInfo(data) {
        if (data.error || !data.gpus || data.gpus.length === 0) {
            document.getElementById('gpu-info').innerHTML = 
                '<div class="alert alert-warning">No GPU detected</div>';
            return;
        }
        
        const gpu = data.gpus[0]; // Show first GPU
        const html = `
            <div class="gpu-status">
                <div class="gpu-status-indicator status-online"></div>
                <strong>${gpu.name}</strong>
            </div>
            <div class="metric-card">
                <div class="metric-value">${(gpu.load * 100).toFixed(1)}%</div>
                <div class="metric-label">GPU Load</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${((gpu.memoryUsed / gpu.memoryTotal) * 100).toFixed(1)}%</div>
                <div class="metric-label">VRAM Usage</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${gpu.temperature}°C</div>
                <div class="metric-label">Temperature</div>
            </div>
        `;
        
        document.getElementById('gpu-info').innerHTML = html;
    }
    
    updateSystemStats(data) {
        if (data.error) return;
        
        // Update CPU chart
        this.updateChart(this.charts.cpu, data.cpu?.usage_percent || 0);
        
        // Update Memory chart
        this.updateChart(this.charts.memory, data.memory?.percent || 0);
        
        // Update GPU chart
        const gpuLoad = data.gpu && data.gpu.length > 0 ? data.gpu[0].load * 100 : 0;
        this.updateChart(this.charts.gpu, gpuLoad);
        
        // Update Network chart (simplified calculation)
        const networkIn = data.network?.bytes_recv || 0;
        const networkOut = data.network?.bytes_sent || 0;
        this.updateNetworkChart(networkIn / 1024, networkOut / 1024); // Convert to KB
        
        // Update system info display
        this.displaySystemInfo(data);
        
        // Update GPU info if available
        if (data.gpu && data.gpu.length > 0) {
            this.displayGPUInfo({ gpus: data.gpu });
        }
    }
    
    updateChart(chart, value) {
        chart.data.datasets[0].data.shift();
        chart.data.datasets[0].data.push(value);
        chart.update('none');
    }
    
    updateNetworkChart(inValue, outValue) {
        this.charts.network.data.datasets[0].data.shift();
        this.charts.network.data.datasets[0].data.push(inValue);
        this.charts.network.data.datasets[1].data.shift();
        this.charts.network.data.datasets[1].data.push(outValue);
        this.charts.network.update('none');
    }
    
    displayBenchmarkResult(data) {
        const resultsDiv = document.getElementById('benchmark-results');
        
        if (data.type === 'matrix_multiply' && data.gpu_result && data.cpu_result) {
            const speedup = data.speedup || (data.cpu_result.time / data.gpu_result.time);
            
            const html = `
                <div class="benchmark-result">
                    <h6><i class="fas fa-calculator"></i> Matrix Multiplication (${data.gpu_result.size}x${data.gpu_result.size})</h6>
                    <div class="benchmark-comparison">
                        <div>
                            <strong>GPU:</strong> ${data.gpu_result.gflops?.toFixed(2) || 'N/A'} GFLOPS 
                            (${data.gpu_result.compute_time?.toFixed(4) || 'N/A'}s)
                        </div>
                        <div class="speedup-badge">${speedup.toFixed(2)}x faster</div>
                    </div>
                    <div class="performance-bar">
                        <div class="performance-bar-fill gpu-bar" style="width: 100%"></div>
                    </div>
                    <div>
                        <strong>CPU:</strong> ${data.cpu_result.gflops?.toFixed(2) || 'N/A'} GFLOPS 
                        (${data.cpu_result.compute_time?.toFixed(4) || 'N/A'}s)
                    </div>
                    <div class="performance-bar">
                        <div class="performance-bar-fill cpu-bar" style="width: ${(1/speedup * 100).toFixed(1)}%"></div>
                    </div>
                </div>
            `;
            
            resultsDiv.innerHTML = html;
        }
    }
    
    displaySingleBenchmarkResult(data, benchmarkType) {
        const resultsDiv = document.getElementById('benchmark-results');
        
        let html = '';
        if (benchmarkType === 'ml_inference') {
            const speedup = data.speedup || 'N/A';
            html = `
                <div class="benchmark-result">
                    <h6><i class="fas fa-brain"></i> ${data.algorithm || 'ML Algorithm'}</h6>
                    <div class="benchmark-comparison">
                        <div><strong>Samples:</strong> ${data.n_samples?.toLocaleString() || 'N/A'}</div>
                        <div><strong>Features:</strong> ${data.n_features || 'N/A'}</div>
                        ${speedup !== 'N/A' ? `<div class="speedup-badge">${speedup.toFixed(2)}x faster</div>` : ''}
                    </div>
                    <div><strong>GPU Time:</strong> ${data.gpu_time?.toFixed(4) || 'N/A'}s</div>
                    ${data.cpu_time ? `<div><strong>CPU Time:</strong> ${data.cpu_time.toFixed(4)}s</div>` : ''}
                </div>
            `;
        } else if (benchmarkType === 'image_processing') {
            const speedup = data.speedup || 'N/A';
            html = `
                <div class="benchmark-result">
                    <h6><i class="fas fa-image"></i> ${data.algorithm || 'Image Processing'}</h6>
                    <div class="benchmark-comparison">
                        <div><strong>Image Size:</strong> ${data.image_size || 'N/A'}</div>
                        ${speedup !== 'N/A' ? `<div class="speedup-badge">${speedup.toFixed(2)}x faster</div>` : ''}
                    </div>
                    <div><strong>Operations:</strong> ${data.operations?.join(', ') || 'N/A'}</div>
                    <div><strong>GPU Time:</strong> ${data.gpu_time?.toFixed(4) || 'N/A'}s</div>
                    ${data.cpu_time ? `<div><strong>CPU Time:</strong> ${data.cpu_time.toFixed(4)}s</div>` : ''}
                </div>
            `;
        }
        
        if (html) {
            resultsDiv.innerHTML = html;
        }
    }
    
    showError(title, message) {
        const resultsDiv = document.getElementById('benchmark-results');
        resultsDiv.innerHTML = `
            <div class="alert alert-danger">
                <h6><i class="fas fa-exclamation-triangle"></i> ${title}</h6>
                <p class="mb-0">${message}</p>
            </div>
        `;
    }
}

// Initialize the app when the DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.gpuDemoApp = new GPUDemoApp();
});