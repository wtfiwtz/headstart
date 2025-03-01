import { Construct } from 'constructs';
import { TerraformStack, TerraformOutput } from 'cdktf';
import { AwsProvider } from '@cdktf/provider-aws/lib/provider';
import { Vpc } from '@cdktf/provider-aws/lib/vpc';
import { SecurityGroup } from '@cdktf/provider-aws/lib/security-group';
import { SecurityGroupRule } from '@cdktf/provider-aws/lib/security-group-rule';
import { Subnet } from '@cdktf/provider-aws/lib/subnet';
import { RouteTable } from '@cdktf/provider-aws/lib/route-table';
import { RouteTableAssociation } from '@cdktf/provider-aws/lib/route-table-association';
import { InternetGateway } from '@cdktf/provider-aws/lib/internet-gateway';
import { NatGateway } from '@cdktf/provider-aws/lib/nat-gateway';
import { Eip } from '@cdktf/provider-aws/lib/eip';
import { Route } from '@cdktf/provider-aws/lib/route';
import { NetworkConfig } from '../../../config';

export interface AwsNetworkStackProps {
  environment: string;
  config: NetworkConfig;
  region: string;
}

export class AwsNetworkStack extends TerraformStack {
  public readonly vpc: Vpc;
  public readonly applicationSecurityGroup: SecurityGroup;
  public readonly loadBalancerSecurityGroup: SecurityGroup;
  public readonly databaseSecurityGroup: SecurityGroup;
  public readonly publicSubnets: Subnet[] = [];
  public readonly privateSubnets: Subnet[] = [];
  public readonly databaseSubnets: Subnet[] = [];

  constructor(scope: Construct, id: string, props: AwsNetworkStackProps) {
    super(scope, id);

    // Define AWS provider
    new AwsProvider(this, 'aws', {
      region: props.region,
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

    // Create Internet Gateway
    const internetGateway = new InternetGateway(this, 'internet-gateway', {
      vpcId: this.vpc.id,
      tags: {
        Name: `${props.config.vpcName}-igw-${props.environment}`,
        Environment: props.environment,
      },
    });

    // Create public route table
    const publicRouteTable = new RouteTable(this, 'public-route-table', {
      vpcId: this.vpc.id,
      tags: {
        Name: `${props.config.vpcName}-public-rt-${props.environment}`,
        Environment: props.environment,
      },
    });

    // Create route to Internet Gateway
    new Route(this, 'public-route', {
      routeTableId: publicRouteTable.id,
      destinationCidrBlock: '0.0.0.0/0',
      gatewayId: internetGateway.id,
    });

    // Create private route table
    const privateRouteTable = new RouteTable(this, 'private-route-table', {
      vpcId: this.vpc.id,
      tags: {
        Name: `${props.config.vpcName}-private-rt-${props.environment}`,
        Environment: props.environment,
      },
    });

    // Create database route table
    const databaseRouteTable = new RouteTable(this, 'database-route-table', {
      vpcId: this.vpc.id,
      tags: {
        Name: `${props.config.vpcName}-database-rt-${props.environment}`,
        Environment: props.environment,
      },
    });

    // Create NAT Gateway if enabled
    let natGateway: NatGateway | undefined;
    if (props.config.enableNatGateway) {
      // Create Elastic IP for NAT Gateway
      const eip = new Eip(this, 'nat-eip', {
        vpc: true,
        tags: {
          Name: `${props.config.vpcName}-nat-eip-${props.environment}`,
          Environment: props.environment,
        },
      });

      // NAT Gateway will be created after the first public subnet
    }

    // Create public subnets
    props.config.publicSubnets.forEach((cidr, index) => {
      const azIndex = index % props.config.azCount;
      const az = `${props.region}${String.fromCharCode(97 + azIndex)}`;
      
      const subnet = new Subnet(this, `public-subnet-${index}`, {
        vpcId: this.vpc.id,
        cidrBlock: cidr,
        availabilityZone: az,
        mapPublicIpOnLaunch: true,
        tags: {
          Name: `${props.config.vpcName}-public-${index + 1}-${props.environment}`,
          Environment: props.environment,
          Type: 'public',
        },
      });
      
      this.publicSubnets.push(subnet);
      
      // Associate with public route table
      new RouteTableAssociation(this, `public-rt-assoc-${index}`, {
        subnetId: subnet.id,
        routeTableId: publicRouteTable.id,
      });

      // Create NAT Gateway in the first public subnet if enabled
      if (props.config.enableNatGateway && index === 0) {
        natGateway = new NatGateway(this, 'nat-gateway', {
          allocationId: new Eip(this, 'nat-eip', {
            vpc: true,
            tags: {
              Name: `${props.config.vpcName}-nat-eip-${props.environment}`,
              Environment: props.environment,
            },
          }).id,
          subnetId: subnet.id,
          tags: {
            Name: `${props.config.vpcName}-nat-${props.environment}`,
            Environment: props.environment,
          },
        });

        // Create route to NAT Gateway
        new Route(this, 'private-route', {
          routeTableId: privateRouteTable.id,
          destinationCidrBlock: '0.0.0.0/0',
          natGatewayId: natGateway.id,
        });
      }
    });

    // Create private subnets
    props.config.privateSubnets.forEach((cidr, index) => {
      const azIndex = index % props.config.azCount;
      const az = `${props.region}${String.fromCharCode(97 + azIndex)}`;
      
      const subnet = new Subnet(this, `private-subnet-${index}`, {
        vpcId: this.vpc.id,
        cidrBlock: cidr,
        availabilityZone: az,
        mapPublicIpOnLaunch: false,
        tags: {
          Name: `${props.config.vpcName}-private-${index + 1}-${props.environment}`,
          Environment: props.environment,
          Type: 'private',
        },
      });
      
      this.privateSubnets.push(subnet);
      
      // Associate with private route table
      new RouteTableAssociation(this, `private-rt-assoc-${index}`, {
        subnetId: subnet.id,
        routeTableId: privateRouteTable.id,
      });
    });

    // Create database subnets
    props.config.databaseSubnets.forEach((cidr, index) => {
      const azIndex = index % props.config.azCount;
      const az = `${props.region}${String.fromCharCode(97 + azIndex)}`;
      
      const subnet = new Subnet(this, `database-subnet-${index}`, {
        vpcId: this.vpc.id,
        cidrBlock: cidr,
        availabilityZone: az,
        mapPublicIpOnLaunch: false,
        tags: {
          Name: `${props.config.vpcName}-database-${index + 1}-${props.environment}`,
          Environment: props.environment,
          Type: 'database',
        },
      });
      
      this.databaseSubnets.push(subnet);
      
      // Associate with database route table
      new RouteTableAssociation(this, `database-rt-assoc-${index}`, {
        subnetId: subnet.id,
        routeTableId: databaseRouteTable.id,
      });
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