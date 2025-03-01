# Multi-Cloud Deployment with CDK and CDKTF

This directory contains the infrastructure as code (IaC) setup for deploying the Dwelling application to multiple cloud providers (AWS, Azure, GCP) using either the Cloud Development Kit for Terraform (CDKTF) or AWS Cloud Development Kit (CDK).

## Prerequisites

- Node.js (v14 or later)
- npm or yarn
- Terraform CLI (v1.0.0 or later) for CDKTF deployments
- AWS CLI, Azure CLI, or Google Cloud SDK (depending on target provider)
- CDK for Terraform (`npm install -g cdktf-cli`) for CDKTF deployments
- AWS CDK (`npm install -g aws-cdk`) for CDK deployments

## Project Structure

```
deploy/
├── bin/                    # Entry point for application
├── lib/                    # Infrastructure stacks and constructs
│   ├── aws/                # AWS-specific stacks
│   │   ├── cdk/            # AWS CDK stacks
│   │   └── cdktf/          # AWS CDKTF stacks
│   ├── azure/              # Azure-specific stacks
│   │   └── cdktf/          # Azure CDKTF stacks
│   └── gcp/                # GCP-specific stacks
│       └── cdktf/          # GCP CDKTF stacks
├── config/                 # Environment-specific configuration
│   ├── aws-cdk.yaml        # AWS CDK configuration
│   ├── aws-cdktf.yaml      # AWS CDKTF configuration
│   ├── azure-cdktf.yaml    # Azure CDKTF configuration
│   ├── gcp-cdktf.yaml      # GCP CDKTF configuration
│   └── schema.json         # Configuration schema
├── scripts/                # Utility scripts for deployment
├── .gitignore              # Git ignore file
├── cdktf.json              # CDKTF configuration
├── package.json            # Node.js dependencies
├── tsconfig.json           # TypeScript configuration
└── README.md               # This file
```

## Available Stacks

For each cloud provider and framework combination, the following stacks are available:

- **NetworkStack**: VPC/VNet, subnets, security groups, etc.
- **DatabaseStack**: Managed database resources (RDS, Azure Database, Cloud SQL)
- **ApplicationStack**: Container services (ECS/Fargate, ACI, Cloud Run)
- **MonitoringStack**: Monitoring and alerting (CloudWatch, Azure Monitor, Cloud Monitoring)

## Configuration

The deployment is configured using YAML files in the `config/` directory. Each file represents a specific provider and framework combination:

- `aws-cdktf.yaml`: AWS deployment using CDKTF
- `aws-cdk.yaml`: AWS deployment using CDK
- `azure-cdktf.yaml`: Azure deployment using CDKTF
- `gcp-cdktf.yaml`: GCP deployment using CDKTF

You can also create environment-specific overrides by adding files with the pattern `{provider}-{framework}-{environment}.yaml`.

### Configuration Schema

The configuration files follow a schema defined in `config/schema.json`. The main sections are:

- **provider**: Cloud provider (aws, azure, gcp)
- **framework**: IaC framework (cdk, cdktf)
- **environment**: Deployment environment (development, staging, production)
- **region**: Cloud provider region
- **application**: Application configuration (container image, resources, etc.)
- **network**: Network configuration (VPC/VNet, subnets, etc.)
- **database**: Database configuration (engine, size, etc.)
- **monitoring**: Monitoring configuration (alarms, dashboards, etc.)

## Getting Started

1. Install dependencies:
   ```
   cd deploy
   npm install
   ```

2. Configure your deployment:
   Edit the configuration files in the `config/` directory to match your requirements.

3. Deploy the infrastructure:
   ```
   # Using the deployment script
   ./scripts/deploy.sh --provider aws --framework cdktf --environment development --command deploy

   # Or using npm scripts
   npm run deploy:aws
   ```

## Environment Configuration

The deployment supports multiple environments (development, staging, production) across different cloud providers.

To deploy to a specific environment:

```
# Using the deployment script
./scripts/deploy.sh --provider aws --framework cdktf --environment production

# Or using npm scripts
ENVIRONMENT=production npm run deploy:aws
```

## Custom Configuration

You can specify a custom configuration file:

```
./scripts/deploy.sh --config custom-config.yaml
```

## Destroying Resources

To destroy the deployed resources:

```
# Using the deployment script
./scripts/deploy.sh --provider aws --framework cdktf --command destroy

# Or using npm scripts
npm run destroy:aws
```

## CI/CD Integration

This deployment setup can be integrated with CI/CD pipelines. Example workflows for GitHub Actions are provided in the `scripts/` directory. 