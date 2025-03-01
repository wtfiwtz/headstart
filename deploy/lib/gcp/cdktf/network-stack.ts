import { Construct } from 'constructs';
import { TerraformStack, TerraformOutput } from 'cdktf';
import { GoogleProvider } from '@cdktf/provider-google/lib/provider';
import { ComputeNetwork } from '@cdktf/provider-google/lib/compute-network';
import { ComputeSubnetwork } from '@cdktf/provider-google/lib/compute-subnetwork';
import { ComputeFirewall } from '@cdktf/provider-google/lib/compute-firewall';
import { ComputeRouter } from '@cdktf/provider-google/lib/compute-router';
import { ComputeRouterNat } from '@cdktf/provider-google/lib/compute-router-nat';
import { NetworkConfig } from '../../../config';

export interface GcpNetworkStackProps {
  environment: string;
  config: NetworkConfig;
  region: string;
}

export class GcpNetworkStack extends TerraformStack {
  public readonly vpc: ComputeNetwork;
  public readonly applicationSecurityGroup: ComputeFirewall;
  public readonly loadBalancerSecurityGroup: ComputeFirewall;
  public readonly databaseSecurityGroup: ComputeFirewall;
  public readonly publicSubnets: ComputeSubnetwork[] = [];
  public readonly privateSubnets: ComputeSubnetwork[] = [];
  public readonly databaseSubnets: ComputeSubnetwork[] = [];

  constructor(scope: Construct, id: string, props: GcpNetworkStackProps) {
    super(scope, id);

    // Define GCP provider
    new GoogleProvider(this, 'google', {
      region: props.region,
    });

    // Create VPC
    this.vpc = new ComputeNetwork(this, 'vpc', {
      name: `${props.config.vpcName}-${props.environment}`,
      autoCreateSubnetworks: false,
      description: `VPC for ${props.environment} environment`,
    });

    // Create subnets
    // Public subnets
    props.config.publicSubnets.forEach((cidr, index) => {
      const subnet = new ComputeSubnetwork(this, `public-subnet-${index}`, {
        name: `${props.config.vpcName}-public-${index + 1}-${props.environment}`,
        network: this.vpc.id,
        ipCidrRange: cidr,
        region: props.region,
        description: `Public subnet ${index + 1} for ${props.environment} environment`,
      });
      
      this.publicSubnets.push(subnet);
    });

    // Private subnets
    props.config.privateSubnets.forEach((cidr, index) => {
      const subnet = new ComputeSubnetwork(this, `private-subnet-${index}`, {
        name: `${props.config.vpcName}-private-${index + 1}-${props.environment}`,
        network: this.vpc.id,
        ipCidrRange: cidr,
        region: props.region,
        description: `Private subnet ${index + 1} for ${props.environment} environment`,
        privateIpGoogleAccess: true,
      });
      
      this.privateSubnets.push(subnet);
    });

    // Database subnets
    props.config.databaseSubnets.forEach((cidr, index) => {
      const subnet = new ComputeSubnetwork(this, `database-subnet-${index}`, {
        name: `${props.config.vpcName}-database-${index + 1}-${props.environment}`,
        network: this.vpc.id,
        ipCidrRange: cidr,
        region: props.region,
        description: `Database subnet ${index + 1} for ${props.environment} environment`,
        privateIpGoogleAccess: true,
      });
      
      this.databaseSubnets.push(subnet);
    });

    // Create Cloud Router for NAT if enabled
    if (props.config.enableNatGateway) {
      const router = new ComputeRouter(this, 'router', {
        name: `${props.config.vpcName}-router-${props.environment}`,
        network: this.vpc.id,
        region: props.region,
      });

      // Create Cloud NAT
      new ComputeRouterNat(this, 'nat', {
        name: `${props.config.vpcName}-nat-${props.environment}`,
        router: router.name,
        region: props.region,
        natIpAllocateOption: 'AUTO_ONLY',
        sourceSubnetworkIpRangesToNat: 'ALL_SUBNETWORKS_ALL_IP_RANGES',
        logConfig: {
          enable: true,
          filter: 'ALL',
        },
      });
    }

    // Create firewall rules (equivalent to security groups)
    this.loadBalancerSecurityGroup = new ComputeFirewall(this, 'lb-firewall', {
      name: `${props.environment}-lb-firewall`,
      network: this.vpc.id,
      description: 'Firewall rules for load balancer',
      allow: [
        {
          protocol: 'tcp',
          ports: ['80', '443'],
        },
      ],
      sourceRanges: ['0.0.0.0/0'],
      targetTags: [`${props.environment}-lb`],
    });

    this.applicationSecurityGroup = new ComputeFirewall(this, 'app-firewall', {
      name: `${props.environment}-app-firewall`,
      network: this.vpc.id,
      description: 'Firewall rules for application',
      allow: [
        {
          protocol: 'tcp',
          ports: ['3000'],
        },
      ],
      sourceRanges: ['0.0.0.0/0'],
      targetTags: [`${props.environment}-app`],
    });

    this.databaseSecurityGroup = new ComputeFirewall(this, 'db-firewall', {
      name: `${props.environment}-db-firewall`,
      network: this.vpc.id,
      description: 'Firewall rules for database',
      allow: [
        {
          protocol: 'tcp',
          ports: ['5432'],
        },
      ],
      sourceRanges: this.privateSubnets.map(subnet => subnet.ipCidrRange),
      targetTags: [`${props.environment}-db`],
    });

    // Outputs
    new TerraformOutput(this, 'vpc-id', {
      value: this.vpc.id,
      description: 'The ID of the VPC',
    });

    new TerraformOutput(this, 'public-subnet-ids', {
      value: this.publicSubnets.map(subnet => subnet.id),
      description: 'The IDs of the public subnets',
    });

    new TerraformOutput(this, 'private-subnet-ids', {
      value: this.privateSubnets.map(subnet => subnet.id),
      description: 'The IDs of the private subnets',
    });

    new TerraformOutput(this, 'database-subnet-ids', {
      value: this.databaseSubnets.map(subnet => subnet.id),
      description: 'The IDs of the database subnets',
    });
  }
} 