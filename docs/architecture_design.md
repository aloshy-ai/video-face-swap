# Video Face Swap API - Architecture Design Document

## 1. Introduction

This document outlines the architecture and design decisions for the Video Face Swap API, a GCP-based service providing AI-powered face swapping capabilities for images and videos. The system is designed to be scalable, maintainable, cost-efficient, and follows Google Cloud best practices.

## 2. System Overview

The Video Face Swap API is a containerized Flask application deployed on Google Cloud Platform. It leverages the InsightFace library for AI-based face swapping and provides a RESTful API for client applications.

### 2.1 Key Use Cases

1. Swap a face from a source image onto a target image
2. Swap a face from a source image onto all frames of a target video
3. Process multiple faces in a single image/video
4. Customize output format and processing parameters

### 2.2 High-Level Architecture

![Architecture Diagram](docs/architecture.png)

The system consists of:

- **Client applications** that consume the Face Swap API
- **Cloud Run** service hosting the API container
- **Artifact Registry** storing the Docker images
- **Cloud Storage** for temporary file handling
- **Cloud Monitoring** for observability
- **Cloud Build** for CI/CD
- **Terraform** for infrastructure as code

## 3. GCP Service Selection and Rationale

### 3.1 Cloud Run

**Decision**: Use Cloud Run instead of GKE, App Engine, or Compute Engine.

**Rationale**:
- **Serverless**: Eliminates infrastructure management
- **Auto-scaling**: Scales from 0 to many instances based on load
- **Cost efficiency**: Pay only for what you use
- **GPU support**: Can be configured with GPUs if needed for inference
- **Container-based**: Allows customization of the runtime environment
- **Integration**: Seamless integration with other GCP services

### 3.2 Artifact Registry

**Decision**: Use Artifact Registry instead of Container Registry.

**Rationale**:
- **Regional storage**: Lower latency and cost
- **Vulnerability scanning**: Built-in security features
- **IAM integration**: Fine-grained access control
- **Lifecycle management**: Better versioning support
- **Future-proofing**: Newer service with ongoing development

### 3.3 Cloud Storage

**Decision**: Use Cloud Storage for temporary files instead of local filesystem.

**Rationale**:
- **Scalability**: No disk space limitations
- **Statelessness**: Better for microservice architecture
- **Availability**: 99.99% SLA
- **Integration**: Native integration with GCP services
- **Cost efficiency**: Automatic lifecycle management

### 3.4 Cloud Monitoring & Logging

**Decision**: Implement custom dashboards and structured logging.

**Rationale**:
- **Visibility**: Real-time metrics for performance monitoring
- **Alerting**: Proactive notification of issues
- **Debugging**: Centralized, structured logs for troubleshooting
- **Insights**: Performance trends and usage patterns
- **SLO tracking**: Ability to define and monitor service level objectives

## 4. Technical Architecture

### 4.1 Container Design

The container is designed following best practices:

- **Base image**: Python 3.10-slim (balance between size and functionality)
- **Multi-layering**: Optimized layer ordering for caching
- **Non-root user**: Security best practice
- **Fixed dependencies**: Pinned versions for reproducibility
- **Pre-loading**: Models loaded at build time to reduce cold starts
- **Health checks**: Built-in monitoring endpoints

### 4.2 API Design

The RESTful API follows these principles:

- **Simplicity**: Clear, focused endpoints
- **Idempotency**: Safe to retry operations
- **Statelessness**: No server-side session state
- **Error handling**: Structured error responses
- **Validation**: Request validation with Pydantic
- **Documentation**: Self-documenting API

### 4.3 Storage Strategy

The application uses a hybrid storage approach:

1. **Ephemeral storage**: Container's filesystem for processing
2. **Persistent storage**: Cloud Storage for outputs and temporary files
3. **Memory caching**: Model weights cached in memory
4. **Lifecycle rules**: Automatic cleanup of temporary files

### 4.4 CI/CD Pipeline

The continuous integration and deployment pipeline:

1. **Build**: Containerizes the application with proper caching
2. **Test**: Runs unit and integration tests
3. **Scan**: Performs vulnerability scanning
4. **Deploy**: Uses Terraform to apply infrastructure changes
5. **Verify**: Confirms deployment success with smoke tests

## 5. GCP Best Practices Implementation

### 5.1 Performance Optimization

- **Concurrency**: Properly configured container concurrency
- **Memory allocation**: Right-sized container memory
- **CPU allocation**: Appropriate CPU provisioning
- **Warm instances**: Configurable minimum instances
- **Connection pooling**: Optimized GCS client

### 5.2 Security Measures

- **Least privilege**: Service accounts with minimal permissions
- **Vulnerability scanning**: Automatic container scanning
- **Non-root execution**: Container runs as non-root user
- **Secret management**: GCP Secret Manager for sensitive data
- **Network security**: VPC connector option for private networking

### 5.3 Cost Optimization

- **Rightsizing**: Appropriate memory and CPU allocation
- **Autoscaling**: Scale to zero when not in use
- **Storage lifecycle**: Automatic deletion of temporary files
- **Request batching**: Process multiple faces in one request
- **Regional deployment**: Reduced data transfer costs

### 5.4 Observability

- **Structured logging**: JSON-formatted logs with context
- **Custom metrics**: Business-relevant metrics
- **Dashboards**: Prebuilt Cloud Monitoring dashboards
- **Alerts**: Proactive notification of issues
- **Tracing**: Request tracing for performance analysis

## 6. Scalability and High Availability

### 6.1 Horizontal Scaling

- **Instance autoscaling**: Based on CPU and request concurrency
- **Regional deployment**: Multiple zones within a region
- **Load balancing**: Managed by Cloud Run

### 6.2 Resiliency

- **Circuit breaking**: Handle downstream service failures
- **Retry logic**: Automatic retries for transient failures
- **Graceful degradation**: Fallback options when services are unavailable
- **Health checks**: Proactive instance health monitoring

## 7. Future Enhancements

### 7.1 Short-term Improvements

- **Caching layer**: Add Redis for improved model caching
- **Async processing**: Background processing for large videos
- **Rate limiting**: Protect against abuse
- **API versioning**: Support for evolving interfaces

### 7.2 Long-term Vision

- **Multi-region deployment**: Global availability
- **AI Platform integration**: Managed model serving
- **GPU acceleration**: For faster processing
- **Custom model training**: Customer-specific models

## 8. Appendix

### 8.1 Infrastructure as Code Details

The Terraform configuration creates:

- Artifact Registry repository
- Cloud Storage bucket with lifecycle rules
- Cloud Run service with proper configuration
- Service accounts with least privilege
- IAM bindings for secure access
- Cloud Monitoring dashboards and alerts

### 8.2 Container Specifications

The Docker container includes:

- Python 3.10 runtime
- InsightFace 0.7.3 for face analysis
- ONNX Runtime for inference
- Flask for API handling
- Gunicorn for production serving
- FFMPEG for video processing

### 8.3 API Endpoints Reference

| Endpoint | Method | Description | Parameters |
|----------|--------|-------------|------------|
| /health | GET | Health check | None |
| /swap | POST | Face swap processing | source, target, output_format, etc. |
| /benchmark | GET | Performance testing | None |
| /model-info | GET | Model information | None |

### 8.4 Networking and Security

#### 8.4.1 Network Architecture

- **Public endpoint**: Cloud Run service with public URL
- **Optional VPC**: VPC connector for private network access
- **Egress control**: Optional configuration for outbound traffic
- **IAM-based access**: Control who can invoke the service

#### 8.4.2 Security Controls

- **Container security**: Non-root user, minimal packages
- **Data encryption**: In-transit and at-rest encryption
- **Access control**: Service identity and IAM policies
- **Vulnerability management**: Automated scanning and patching

### 8.5 Cost Analysis

#### 8.5.1 Cloud Run Costs

- **CPU/Memory**: Right-sized for workload (2 CPU, 4GB RAM)
- **Requests**: Pay-per-use with concurrency of 5
- **Idle Instances**: Configurable minimum instances

#### 8.5.2 Storage Costs

- **Artifact Registry**: Container storage (~1GB)
- **Cloud Storage**: Temporary file storage with 1-day lifecycle
- **Network egress**: Data transfer for API responses

#### 8.5.3 Cost Optimization Strategies

- **Compression**: Reduce storage and transfer costs
- **Instance tuning**: Balance instances vs. concurrency
- **Cold start mitigation**: Minimum instances vs. cost

## 9. Operational Considerations

### 9.1 Deployment Strategy

- **Blue/Green Deployment**: Zero-downtime updates
- **Canary Releases**: Gradual rollout of new versions
- **Rollback Plan**: Immediate reversion to previous version

### 9.2 Monitoring and Alerting

- **SLI/SLO Monitoring**: Track service level indicators
- **Error Rate Alerting**: Notification on elevated error rates
- **Latency Monitoring**: Track processing times for images/videos
- **Resource Utilization**: CPU, memory, and connection monitoring

### 9.3 Backup and Recovery

- **Image Versioning**: All container images versioned in Artifact Registry
- **Infrastructure as Code**: Terraform state in Cloud Storage
- **Disaster Recovery**: Regional service with documented recovery procedures

### 9.4 Operational Playbooks

- **Incident Response**: Steps for handling service disruptions
- **Scaling Procedures**: How to adjust capacity for demand
- **Maintenance Windows**: Planned downtime procedures

## 10. Compliance and Governance

### 10.1 Data Handling

- **Data Residency**: Regional deployment options
- **Data Retention**: Temporary files deleted after processing
- **Data Processing**: All processing performed server-side

### 10.2 Audit and Logging

- **Access Logs**: All API calls logged with identity
- **Processing Logs**: Face swap operations logged
- **Error Logs**: Detailed error information captured

### 10.3 Privacy Considerations

- **Face Data**: No permanent storage of facial recognition data
- **Input Files**: Processed and removed after completion
- **User Consent**: Client applications responsible for consent

## 11. Conclusion

The Video Face Swap API architecture is designed to provide a scalable, efficient, and secure platform for face swapping operations. By leveraging GCP's managed services and following cloud-native best practices, the system achieves a balance of performance, cost, and maintainability.

The serverless approach using Cloud Run enables the service to scale automatically with demand while minimizing operational overhead. Integration with GCP's storage, monitoring, and security services provides a robust foundation for the application.

This architecture supports the current requirements while remaining flexible enough to accommodate future enhancements and scaling needs.
