#!/bin/bash
set -e

# Default values
ENVIRONMENT="development"
PROVIDER="aws"
FRAMEWORK="cdktf"
COMMAND="deploy"
CONFIG_FILE=""

print_usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -e, --environment ENV    Specify environment (development, staging, production)"
  echo "  -p, --provider PROVIDER  Specify cloud provider (aws, azure, gcp)"
  echo "  -f, --framework FRAMEWORK Specify IaC framework (cdk, cdktf)"
  echo "  -c, --command CMD        Specify command (deploy, destroy, plan, synth)"
  echo "  -C, --config FILE        Specify a custom config file"
  echo "  -h, --help               Display this help message"
}

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -e|--environment)
      ENVIRONMENT="$2"
      shift
      shift
      ;;
    -p|--provider)
      PROVIDER="$2"
      shift
      shift
      ;;
    -f|--framework)
      FRAMEWORK="$2"
      shift
      shift
      ;;
    -c|--command)
      COMMAND="$2"
      shift
      shift
      ;;
    -C|--config)
      CONFIG_FILE="$2"
      shift
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(development|staging|production)$ ]]; then
  echo "Error: Environment must be one of: development, staging, production"
  exit 1
fi

# Validate provider
if [[ ! "$PROVIDER" =~ ^(aws|azure|gcp)$ ]]; then
  echo "Error: Provider must be one of: aws, azure, gcp"
  exit 1
fi

# Validate framework
if [[ ! "$FRAMEWORK" =~ ^(cdk|cdktf)$ ]]; then
  echo "Error: Framework must be one of: cdk, cdktf"
  exit 1
fi

# Validate command
if [[ ! "$COMMAND" =~ ^(deploy|destroy|plan|synth)$ ]]; then
  echo "Error: Command must be one of: deploy, destroy, plan, synth"
  exit 1
fi

# Set environment variables
export ENVIRONMENT=$ENVIRONMENT
export PROVIDER=$PROVIDER
export FRAMEWORK=$FRAMEWORK

# If a custom config file is specified, set it as an environment variable
if [[ -n "$CONFIG_FILE" ]]; then
  export CONFIG_FILE=$CONFIG_FILE
fi

# Navigate to the deploy directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"
cd "$DEPLOY_DIR"

echo "=== HeadStart Deployment ==="
echo "Environment: $ENVIRONMENT"
echo "Provider: $PROVIDER"
echo "Framework: $FRAMEWORK"
echo "Command: $COMMAND"
if [[ -n "$CONFIG_FILE" ]]; then
  echo "Config File: $CONFIG_FILE"
fi
echo "================================"

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
  echo "Installing dependencies..."
  npm install
fi

# Execute the requested command based on the framework
if [[ "$FRAMEWORK" == "cdktf" ]]; then
  case $COMMAND in
    deploy)
      echo "Deploying infrastructure to $PROVIDER ($ENVIRONMENT)..."
      npx cdktf deploy --all
      ;;
    destroy)
      echo "Destroying infrastructure in $PROVIDER ($ENVIRONMENT)..."
      npx cdktf destroy --all
      ;;
    plan)
      echo "Planning infrastructure changes for $PROVIDER ($ENVIRONMENT)..."
      npx cdktf plan --all
      ;;
    synth)
      echo "Synthesizing Terraform configuration for $PROVIDER ($ENVIRONMENT)..."
      npx cdktf synth
      ;;
  esac
elif [[ "$FRAMEWORK" == "cdk" ]]; then
  case $COMMAND in
    deploy)
      echo "Deploying infrastructure to $PROVIDER ($ENVIRONMENT) using CDK..."
      npx cdk deploy --all
      ;;
    destroy)
      echo "Destroying infrastructure in $PROVIDER ($ENVIRONMENT) using CDK..."
      npx cdk destroy --all
      ;;
    plan)
      echo "Planning infrastructure changes for $PROVIDER ($ENVIRONMENT) using CDK..."
      npx cdk diff
      ;;
    synth)
      echo "Synthesizing CloudFormation configuration for $PROVIDER ($ENVIRONMENT)..."
      npx cdk synth
      ;;
  esac
fi

echo "Command completed successfully!" 