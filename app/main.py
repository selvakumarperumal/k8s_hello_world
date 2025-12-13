"""
FastAPI Hello World Application

A simple FastAPI application for demonstrating AWS EKS deployment.
"""

from fastapi import FastAPI

# Create FastAPI application instance
app = FastAPI(
    title="FastAPI Hello World",
    description="A simple Hello World API deployed on AWS EKS",
    version="1.0.0"
)


@app.get("/")
def read_root():
    """
    Root endpoint that returns a Hello World message.
    
    Returns:
        dict: A JSON response with a greeting message
    """
    return {"message": "Hello World"}


@app.get("/health")
def health_check():
    """
    Health check endpoint for Kubernetes liveness/readiness probes.
    
    Returns:
        dict: A JSON response indicating the service is healthy
    """
    return {"status": "healthy"}
