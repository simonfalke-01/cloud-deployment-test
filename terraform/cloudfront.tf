# Origin Access Control for CloudFront
resource "aws_cloudfront_origin_access_control" "gpu_demo" {
  name                              = "gpu-demo-oac"
  description                       = "OAC for GPU Demo Application"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "gpu_demo" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "GPU Demo Application CDN"

  origin {
    domain_name = aws_eip.gpu_demo.public_ip
    origin_id   = "gpu-demo-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "gpu-demo-origin"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["Host", "CloudFront-Forwarded-Proto", "CloudFront-Is-Mobile-Viewer", "CloudFront-Is-Tablet-Viewer"]

      cookies {
        forward = "none"
      }
    }

    # Cache settings for dynamic content
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 86400
  }

  # Cache behavior for static assets
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "gpu-demo-origin"
    compress         = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  # Cache behavior for API endpoints (no caching)
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "gpu-demo-origin"
    compress         = false

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  # Cache behavior for WebSocket connections
  ordered_cache_behavior {
    path_pattern     = "/socket.io/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "gpu-demo-origin"
    compress         = false

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # Custom error pages for better user experience
  custom_error_response {
    error_code            = 503
    error_caching_min_ttl = 0
    response_code         = 503
    response_page_path    = "/error.html"
  }

  custom_error_response {
    error_code            = 502
    error_caching_min_ttl = 0
    response_code         = 502
    response_page_path    = "/error.html"
  }

  tags = merge(local.common_tags, {
    Name = "gpu-demo-cloudfront"
  })

  # Wait for EIP to be associated before creating distribution
  depends_on = [aws_eip.gpu_demo]
}

# Route53 Health Check for the instance
resource "aws_route53_health_check" "gpu_demo" {
  fqdn                            = aws_eip.gpu_demo.public_ip
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/health"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_alarm_region         = var.aws_region
  insufficient_data_health_status = "Failure"

  tags = merge(local.common_tags, {
    Name = "gpu-demo-health-check"
  })
}
