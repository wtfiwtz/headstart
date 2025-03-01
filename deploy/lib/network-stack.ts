import { Construct } from 'constructs';
import { TerraformStack, TerraformOutput } from 'cdktf';
import { AwsProvider } from '@cdktf/provider-aws/lib/provider';
import { Vpc } from '@cdktf/provider-aws/lib/vpc';
import { SecurityGroup } from '@cdktf/provider-aws/lib/security-group';
import { SecurityGroupRule } from '@cdktf/provider-aws/lib/security-group-rule';
import { NetworkConfig } from '../config';

export interface NetworkStackProps {
  environment: string;
  config: NetworkConfig;
}

export class NetworkStack extends TerraformStack {
  public readonly vpc: Vpc;
  public readonly applicationSecurityGroup: SecurityGroup;
  public readonly loadBalancerSecurityGroup: SecurityGroup;
  public readonly databaseSecurityGroup: SecurityGroup;

  constructor(scope: Construct, id: string, props: NetworkStackProps) {
    super(scope, id);

    // Define AWS provider
    new AwsProvider(this, 'aws', {
      region: process.env.AWS_REGION || 'us-east-1',
    });

    // Create VPC
    this.vpc = new Vpc(this, 'vpc', {
      cidrBlock: props.config.cidr,
      enableDnsHostnames: true,
      enableDnsSupport: true,
      tags: {
        Name: `${props.config.vpcName}-${props.environment}`,
        Environment: props.environment,
      },
    });

    // Create public subnets
    const publicSubnets = props.config.publicSubnets.map((cidr, index) => {
      const azIndex = index % props.config.azCount;
      const az = `${process.env.AWS_REGION || 'us-east-1'}${String.fromCharCode(97 + azIndex)}`;
      
      return {
        cidrBlock: cidr,
        availabilityZone: az,
        mapPublicIpOnLaunch: true,
        tags: {
          Name: `${props.config.vpcName}-public-${index + 1}`,
          Environment: props.environment,
          Type: 'public',
        },
      };
    });

    // Create private subnets
    const privateSubnets = props.config.privateSubnets.map((cidr, index) => {
      const azIndex = index % props.config.azCount;
      const az = `${process.env.AWS_REGION || 'us-east-1'}${String.fromCharCode(97 + azIndex)}`;
      
      return {
        cidrBlock: cidr,
        availabilityZone: az,
        mapPublicIpOnLaunch: false,
        tags: {
          Name: `${props.config.vpcName}-private-${index + 1}`,
          Environment: props.environment,
          Type: 'private',
        },
      };
    });

    // Create database subnets
    const databaseSubnets = props.config.databaseSubnets.map((cidr, index) => {
      const azIndex = index % props.config.azCount;
      const az = `${process.env.AWS_REGION || 'us-east-1'}${String.fromCharCode(97 + azIndex)}`;
      
      return {
        cidrBlock: cidr,
        availabilityZone: az,
        mapPublicIpOnLaunch: false,
        tags: {
          Name: `${props.config.vpcName}-database-${index + 1}`,
          Environment: props.environment,
          Type: 'database',
        },
      };
    });

    // Create security groups
    this.loadBalancerSecurityGroup = new SecurityGroup(this, 'lb-sg', {
      vpcId: this.vpc.id,
      name: `${props.environment}-lb-sg`,
      description: 'Security group for load balancer',
      tags: {
        Name: `${props.environment}-lb-sg`,
        Environment: props.environment,
      },
    });

    this.applicationSecurityGroup = new SecurityGroup(this, 'app-sg', {
      vpcId: this.vpc.id,
      name: `${props.environment}-app-sg`,
      description: 'Security group for application',
      tags: {
        Name: `${props.environment}-app-sg`,
        Environment: props.environment,
      },
    });

    this.databaseSecurityGroup = new SecurityGroup(this, 'db-sg', {
      vpcId: this.vpc.id,
      name: `${props.environment}-db-sg`,
      description: 'Security group for database',
      tags: {
        Name: `${props.environment}-db-sg`,
        Environment: props.environment,
      },
    });

    // Security group rules for load balancer
    new SecurityGroupRule(this, 'lb-http-ingress', {
      securityGroupId: this.loadBalancerSecurityGroup.id,
      type: 'ingress',
      fromPort: 80,
      toPort: 80,
      protocol: 'tcp',
      cidrBlocks: ['0.0.0.0/0'],
      description: 'Allow HTTP traffic from anywhere',
    });

    new SecurityGroupRule(this, 'lb-https-ingress', {
      securityGroupId: this.loadBalancerSecurityGroup.id,
      type: 'ingress',
      fromPort: 443,
      toPort: 443,
      protocol: 'tcp',
      cidrBlocks: ['0.0.0.0/0'],
      description: 'Allow HTTPS traffic from anywhere',
    });

    new SecurityGroupRule(this, 'lb-egress', {
      securityGroupId: this.loadBalancerSecurityGroup.id,
      type: 'egress',
      fromPort: 0,
      toPort: 0,
      protocol: '-1',
      cidrBlocks: ['0.0.0.0/0'],
      description: 'Allow all outbound traffic',
    });

    // Security group rules for application
    new SecurityGroupRule(this, 'app-http-ingress', {
      securityGroupId: this.applicationSecurityGroup.id,
      type: 'ingress',
      fromPort: 3000,
      toPort: 3000,
      protocol: 'tcp',
      sourceSecurityGroupId: this.loadBalancerSecurityGroup.id,
      description: 'Allow HTTP traffic from load balancer',
    });

    new SecurityGroupRule(this, 'app-egress', {
      securityGroupId: this.applicationSecurityGroup.id,
      type: 'egress',
      fromPort: 0,
      toPort: 0,
      protocol: '-1',
      cidrBlocks: ['0.0.0.0/0'],
      description: 'Allow all outbound traffic',
    });

    // Security group rules for database
    new SecurityGroupRule(this, 'db-postgres-ingress', {
      securityGroupId: this.databaseSecurityGroup.id,
      type: 'ingress',
      fromPort: 5432,
      toPort: 5432,
      protocol: 'tcp',
      sourceSecurityGroupId: this.applicationSecurityGroup.id,
      description: 'Allow PostgreSQL traffic from application',
    });

    new SecurityGroupRule(this, 'db-egress', {
      securityGroupId: this.databaseSecurityGroup.id,
      type: 'egress',
      fromPort: 0,
      toPort: 0,
      protocol: '-1',
      cidrBlocks: ['0.0.0.0/0'],
      description: 'Allow all outbound traffic',
    });

    // Outputs
    new TerraformOutput(this, 'vpc-id', {
      value: this.vpc.id,
      description: 'The ID of the VPC',
    });

    new TerraformOutput(this, 'app-security-group-id', {
      value: this.applicationSecurityGroup.id,
      description: 'The ID of the application security group',
    });

    new TerraformOutput(this, 'lb-security-group-id', {
      value: this.loadBalancerSecurityGroup.id,
      description: 'The ID of the load balancer security group',
    });

    new TerraformOutput(this, 'db-security-group-id', {
      value: this.databaseSecurityGroup.id,
      description: 'The ID of the database security group',
    });
  }
} 