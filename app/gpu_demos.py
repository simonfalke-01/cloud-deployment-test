#!/usr/bin/env python3
import time
import numpy as np
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

try:
    import cupy as cp
    import cuml
    from cuml.cluster import KMeans as cuKMeans
    from cuml.linear_model import LinearRegression as cuLinearRegression
    from cuml.preprocessing import StandardScaler as cuStandardScaler
    CUML_AVAILABLE = True
    logger.info("CUML and CuPy available")
except ImportError as e:
    CUML_AVAILABLE = False
    logger.warning(f"CUML/CuPy not available: {e}")
    cp = None

try:
    import cv2
    CV2_AVAILABLE = True
except ImportError:
    CV2_AVAILABLE = False
    logger.warning("OpenCV not available")

class GPUDemos:
    """GPU-accelerated demonstration functions using CUML and CuPy"""
    
    def __init__(self):
        self.cuml_available = CUML_AVAILABLE
        self.cv2_available = CV2_AVAILABLE
        
        if not self.cuml_available:
            logger.warning("CUML not available - some demos will be disabled")
    
    def matrix_multiplication_benchmark(self, size=1024):
        """GPU matrix multiplication benchmark using CuPy"""
        if not self.cuml_available:
            return {'error': 'CuPy not available', 'time': 0, 'gflops': 0}
        
        try:
            logger.info(f"Running GPU matrix multiplication benchmark (size: {size}x{size})")
            
            # Create random matrices on GPU
            start_time = time.time()
            a_gpu = cp.random.random((size, size), dtype=cp.float32)
            b_gpu = cp.random.random((size, size), dtype=cp.float32)
            
            # Warm-up
            _ = cp.dot(a_gpu, b_gpu)
            cp.cuda.Stream.null.synchronize()
            
            # Actual benchmark
            start_compute = time.time()
            c_gpu = cp.dot(a_gpu, b_gpu)
            cp.cuda.Stream.null.synchronize()
            end_time = time.time()
            
            compute_time = end_time - start_compute
            total_time = end_time - start_time
            
            # Calculate GFLOPS
            operations = 2 * size**3  # multiply-add operations
            gflops = operations / (compute_time * 1e9)
            
            # Get GPU memory info
            mempool = cp.get_default_memory_pool()
            memory_used = mempool.used_bytes() / (1024**2)  # MB
            
            result = {
                'size': size,
                'compute_time': compute_time,
                'total_time': total_time,
                'gflops': gflops,
                'memory_used_mb': memory_used,
                'device': cp.cuda.Device().id,
                'timestamp': datetime.now().isoformat()
            }
            
            logger.info(f"GPU benchmark completed: {gflops:.2f} GFLOPS in {compute_time:.4f}s")
            return result
            
        except Exception as e:
            logger.error(f"GPU matrix multiplication error: {e}")
            return {'error': str(e), 'time': 0, 'gflops': 0}
    
    def cpu_matrix_multiplication_benchmark(self, size=1024):
        """CPU matrix multiplication benchmark for comparison"""
        try:
            logger.info(f"Running CPU matrix multiplication benchmark (size: {size}x{size})")
            
            # Create random matrices on CPU
            start_time = time.time()
            a_cpu = np.random.random((size, size)).astype(np.float32)
            b_cpu = np.random.random((size, size)).astype(np.float32)
            
            # Actual benchmark
            start_compute = time.time()
            c_cpu = np.dot(a_cpu, b_cpu)
            end_time = time.time()
            
            compute_time = end_time - start_compute
            total_time = end_time - start_time
            
            # Calculate GFLOPS
            operations = 2 * size**3
            gflops = operations / (compute_time * 1e9)
            
            result = {
                'size': size,
                'compute_time': compute_time,
                'total_time': total_time,
                'gflops': gflops,
                'timestamp': datetime.now().isoformat()
            }
            
            logger.info(f"CPU benchmark completed: {gflops:.2f} GFLOPS in {compute_time:.4f}s")
            return result
            
        except Exception as e:
            logger.error(f"CPU matrix multiplication error: {e}")
            return {'error': str(e), 'time': 0, 'gflops': 0}
    
    def ml_inference_benchmark(self):
        """Machine learning inference benchmark using CUML"""
        if not self.cuml_available:
            return {'error': 'CUML not available'}
        
        try:
            logger.info("Running ML inference benchmark")
            
            # Generate synthetic data
            n_samples = 100000
            n_features = 100
            n_clusters = 10
            
            start_time = time.time()
            
            # Create data on GPU
            X_gpu = cp.random.random((n_samples, n_features), dtype=cp.float32)
            
            # GPU K-means clustering
            gpu_start = time.time()
            kmeans_gpu = cuKMeans(n_clusters=n_clusters, random_state=42)
            labels_gpu = kmeans_gpu.fit_predict(X_gpu)
            cp.cuda.Stream.null.synchronize()
            gpu_time = time.time() - gpu_start
            
            # CPU comparison (using scikit-learn)
            try:
                from sklearn.cluster import KMeans
                X_cpu = cp.asnumpy(X_gpu)
                
                cpu_start = time.time()
                kmeans_cpu = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
                labels_cpu = kmeans_cpu.fit_predict(X_cpu)
                cpu_time = time.time() - cpu_start
                
                speedup = cpu_time / gpu_time
                
            except ImportError:
                cpu_time = None
                speedup = None
            
            total_time = time.time() - start_time
            
            result = {
                'algorithm': 'K-Means Clustering',
                'n_samples': n_samples,
                'n_features': n_features,
                'n_clusters': n_clusters,
                'gpu_time': gpu_time,
                'cpu_time': cpu_time,
                'speedup': speedup,
                'total_time': total_time,
                'timestamp': datetime.now().isoformat()
            }
            
            logger.info(f"ML benchmark completed: {speedup:.2f}x speedup" if speedup else "ML benchmark completed")
            return result
            
        except Exception as e:
            logger.error(f"ML inference error: {e}")
            return {'error': str(e)}
    
    def linear_regression_benchmark(self):
        """Linear regression benchmark using CUML"""
        if not self.cuml_available:
            return {'error': 'CUML not available'}
        
        try:
            logger.info("Running linear regression benchmark")
            
            n_samples = 1000000
            n_features = 50
            
            start_time = time.time()
            
            # Generate synthetic regression data
            X_gpu = cp.random.random((n_samples, n_features), dtype=cp.float32)
            true_coef = cp.random.random(n_features, dtype=cp.float32)
            y_gpu = X_gpu.dot(true_coef) + cp.random.normal(0, 0.1, n_samples, dtype=cp.float32)
            
            # GPU Linear Regression
            gpu_start = time.time()
            scaler_gpu = cuStandardScaler()
            X_scaled_gpu = scaler_gpu.fit_transform(X_gpu)
            
            lr_gpu = cuLinearRegression()
            lr_gpu.fit(X_scaled_gpu, y_gpu)
            predictions_gpu = lr_gpu.predict(X_scaled_gpu)
            cp.cuda.Stream.null.synchronize()
            gpu_time = time.time() - gpu_start
            
            # Calculate R²
            y_mean = cp.mean(y_gpu)
            ss_res = cp.sum((y_gpu - predictions_gpu) ** 2)
            ss_tot = cp.sum((y_gpu - y_mean) ** 2)
            r2_score = 1 - (ss_res / ss_tot)
            
            # CPU comparison
            try:
                from sklearn.linear_model import LinearRegression
                from sklearn.preprocessing import StandardScaler
                
                X_cpu = cp.asnumpy(X_gpu)
                y_cpu = cp.asnumpy(y_gpu)
                
                cpu_start = time.time()
                scaler_cpu = StandardScaler()
                X_scaled_cpu = scaler_cpu.fit_transform(X_cpu)
                
                lr_cpu = LinearRegression()
                lr_cpu.fit(X_scaled_cpu, y_cpu)
                predictions_cpu = lr_cpu.predict(X_scaled_cpu)
                cpu_time = time.time() - cpu_start
                
                speedup = cpu_time / gpu_time
                
            except ImportError:
                cpu_time = None
                speedup = None
            
            total_time = time.time() - start_time
            
            result = {
                'algorithm': 'Linear Regression',
                'n_samples': n_samples,
                'n_features': n_features,
                'r2_score': float(r2_score),
                'gpu_time': gpu_time,
                'cpu_time': cpu_time,
                'speedup': speedup,
                'total_time': total_time,
                'timestamp': datetime.now().isoformat()
            }
            
            logger.info(f"Linear regression completed: R² = {r2_score:.4f}, {speedup:.2f}x speedup" if speedup else f"Linear regression completed: R² = {r2_score:.4f}")
            return result
            
        except Exception as e:
            logger.error(f"Linear regression error: {e}")
            return {'error': str(e)}
    
    def image_processing_benchmark(self):
        """Image processing benchmark using CuPy"""
        if not self.cuml_available:
            return {'error': 'CuPy not available'}
        
        try:
            logger.info("Running image processing benchmark")
            
            # Create a large synthetic image
            height, width = 4096, 4096
            channels = 3
            
            start_time = time.time()
            
            # Create random image data on GPU
            image_gpu = cp.random.randint(0, 256, (height, width, channels), dtype=cp.uint8)
            
            gpu_start = time.time()
            
            # Apply various image processing operations
            # 1. Convert to grayscale
            gray_gpu = cp.mean(image_gpu, axis=2, dtype=cp.uint8)
            
            # 2. Apply Gaussian blur approximation (separable kernel)
            kernel_size = 15
            sigma = 3.0
            kernel = cp.exp(-0.5 * (cp.arange(kernel_size) - kernel_size//2)**2 / sigma**2)
            kernel = kernel / cp.sum(kernel)
            
            # Horizontal blur
            blurred_h = cp.convolve(gray_gpu.ravel(), kernel, mode='same').reshape(gray_gpu.shape)
            # Vertical blur  
            blurred_v = cp.convolve(blurred_h.T.ravel(), kernel, mode='same').reshape(blurred_h.T.shape).T
            
            # 3. Edge detection (Sobel operator)
            sobel_x = cp.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], dtype=cp.float32)
            sobel_y = cp.array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]], dtype=cp.float32)
            
            # Simple edge detection approximation
            edges = cp.abs(cp.diff(blurred_v, axis=0, prepend=0)) + cp.abs(cp.diff(blurred_v, axis=1, prepend=0))
            
            # 4. Histogram calculation
            histogram = cp.histogram(gray_gpu, bins=256, range=(0, 256))[0]
            
            cp.cuda.Stream.null.synchronize()
            gpu_time = time.time() - gpu_start
            
            # CPU comparison
            try:
                image_cpu = cp.asnumpy(image_gpu)
                
                cpu_start = time.time()
                gray_cpu = np.mean(image_cpu, axis=2, dtype=np.uint8)
                
                # Simple blur
                from scipy.ndimage import gaussian_filter
                blurred_cpu = gaussian_filter(gray_cpu.astype(np.float32), sigma=sigma)
                
                # Edge detection
                edges_cpu = np.abs(np.diff(blurred_cpu, axis=0, prepend=0)) + np.abs(np.diff(blurred_cpu, axis=1, prepend=0))
                
                # Histogram
                histogram_cpu = np.histogram(gray_cpu, bins=256, range=(0, 256))[0]
                
                cpu_time = time.time() - cpu_start
                speedup = cpu_time / gpu_time
                
            except ImportError:
                cpu_time = None
                speedup = None
            
            total_time = time.time() - start_time
            
            result = {
                'algorithm': 'Image Processing Pipeline',
                'image_size': f"{width}x{height}x{channels}",
                'operations': ['grayscale', 'blur', 'edge_detection', 'histogram'],
                'gpu_time': gpu_time,
                'cpu_time': cpu_time,
                'speedup': speedup,
                'total_time': total_time,
                'memory_used_mb': image_gpu.nbytes / (1024**2),
                'timestamp': datetime.now().isoformat()
            }
            
            logger.info(f"Image processing completed: {speedup:.2f}x speedup" if speedup else "Image processing completed")
            return result
            
        except Exception as e:
            logger.error(f"Image processing error: {e}")
            return {'error': str(e)}
    
    def get_gpu_status(self):
        """Get current GPU status"""
        if not self.cuml_available:
            return {'error': 'CuPy not available'}
        
        try:
            device = cp.cuda.Device()
            mempool = cp.get_default_memory_pool()
            
            status = {
                'device_id': device.id,
                'device_name': device.attributes.get('name', 'Unknown'),
                'memory_pool_used_mb': mempool.used_bytes() / (1024**2),
                'memory_pool_total_mb': mempool.total_bytes() / (1024**2),
                'cuda_version': cp.cuda.runtime.runtimeGetVersion(),
                'cuml_available': self.cuml_available,
                'timestamp': datetime.now().isoformat()
            }
            
            return status
            
        except Exception as e:
            logger.error(f"GPU status error: {e}")
            return {'error': str(e)}