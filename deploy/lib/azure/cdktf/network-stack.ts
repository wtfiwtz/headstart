import { Construct } from 'constructs';
import { TerraformStack, TerraformOutput } from 'cdktf';
import { AzurermProvider } from '@cdktf/provider-azurerm/lib/provider';
import { VirtualNetwork } from '@cdktf/provider-azurerm/lib/virtual-network';
import { Subnet } from '@cdktf/provider-azurerm/lib/subnet';
import { NetworkSecurityGroup } from '@cdktf/provider-azurerm/lib/network-security-group';
import { NetworkSecurityRule } from '@cdktf/provider-azurerm/lib/network-security-rule';
import { ResourceGroup } from '@cdktf/provider-azurerm/lib/resource-group';
import { NetworkConfig } from '../../../config';

export interface AzureNetworkStackProps {
  environment: string;
  config: NetworkConfig;
  region: string;
}

export class AzureNetworkStack extends TerraformStack {
  public readonly vnet: VirtualNetwork;
  public readonly applicationSecurityGroup: NetworkSecurityGroup;
  public readonly loadBalancerSecurityGroup: NetworkSecurityGroup;
  public readonly databaseSecurityGroup: NetworkSecurityGroup;
  public readonly publicSubnets: Subnet[] = [];
  public readonly privateSubnets: Subnet[] = [];
  public readonly databaseSubnets: Subnet[] = [];
  public readonly resourceGroup: ResourceGroup;

  constructor(scope: Construct, id: string, props: AzureNetworkStackProps) {
    super(scope, id);

    // Define Azure provider
    new AzurermProvider(this, 'azure', {
      features: {},
    });

    // Create Resource Group
    this.resourceGroup = new ResourceGroup(this, 'resource-group', {
      name: `${props.config.vpcName}-${props.environment}-rg`,
      location: props.region,
      tags: {
        Environment: props.environment,
      },
    });

    // Create Virtual Network (equivalent to VPC)
    this.vnet = new VirtualNetwork(this, 'vnet', {
      name: `${props.config.vpcName}-${props.environment}`,
      resourceGroupName: this.resourceGroup.name,
      location: props.region,
      addressSpace: [props.config.cidr],
      tags: {
        Environment: props.environment,
      },
    });

    // Create Network Security Groups (equivalent to Security Groups)
    this.loadBalancerSecurityGroup = new NetworkSecurityGroup(this, 'lb-nsg', {
      name: `${props.environment}-lb-nsg`,
      resourceGroupName: this.resourceGroup.name,
      location: props.region,
      tags: {
        Environment: props.environment,
      },
    });

    this.applicationSecurityGroup = new NetworkSecurityGroup(this, 'app-nsg', {
      name: `${props.environment}-app-nsg`,
      resourceGroupName: this.resourceGroup.name,
      location: props.region,
      tags: {
        Environment: props.environment,
      },
    });

    this.databaseSecurityGroup = new NetworkSecurityGroup(this, 'db-nsg', {
      name: `${props.environment}-db-nsg`,
      resourceGroupName: this.resourceGroup.name,
      location: props.region,
      tags: {
        Environment: props.environment,
      },
    });

    // Create subnets
    // Public subnets
    props.config.publicSubnets.forEach((cidr, index) => {
      const subnet = new Subnet(this, `public-subnet-${index}`, {
        name: `${props.config.vpcName}-public-${index + 1}-${props.environment}`,
        resourceGroupName: this.resourceGroup.name,
        virtualNetworkName: this.vnet.name,
        addressPrefixes: [cidr],
      });
      
      this.publicSubnets.push(subnet);
    });

    // Private subnets
    props.config.privateSubnets.forEach((cidr, index) => {
      const subnet = new Subnet(this, `private-subnet-${index}`, {
        name: `${props.config.vpcName}-private-${index + 1}-${props.environment}`,
        resourceGroupName: this.resourceGroup.name,
        virtualNetworkName: this.vnet.name,
        addressPrefixes: [cidr],
      });
      
      this.privateSubnets.push(subnet);
    });

    // Database subnets
    props.config.databaseSubnets.forEach((cidr, index) => {
      const subnet = new Subnet(this, `database-subnet-${index}`, {
        name: `${props.config.vpcName}-database-${index + 1}-${props.environment}`,
        resourceGroupName: this.resourceGroup.name,
        virtualNetworkName: this.vnet.name,
        addressPrefixes: [cidr],
      });
      
      this.databaseSubnets.push(subnet);
    });

    // Security rules for load balancer
    new NetworkSecurityRule(this, 'lb-http-rule', {
      name: 'allow-http',
      resourceGroupName: this.resourceGroup.name,
      networkSecurityGroupName: this.loadBalancerSecurityGroup.name,
      priority: 100,
      direction: 'Inbound',
      access: 'Allow',
      protocol: 'Tcp',
      sourcePortRange: '*',
      destinationPortRange: '80',
      sourceAddressPrefix: '*',
      destinationAddressPrefix: '*',
    });

    new NetworkSecurityRule(this, 'lb-https-rule', {
      name: 'allow-https',
      resourceGroupName: this.resourceGroup.name,
      networkSecurityGroupName: this.loadBalancerSecurityGroup.name,
      priority: 110,
      direction: 'Inbound',
      access: 'Allow',
      protocol: 'Tcp',
      sourcePortRange: '*',
      destinationPortRange: '443',
      sourceAddressPrefix: '*',
      destinationAddressPrefix: '*',
    });

    // Security rules for application
    new NetworkSecurityRule(this, 'app-http-rule', {
      name: 'allow-app-http',
      resourceGroupName: this.resourceGroup.name,
      networkSecurityGroupName: this.applicationSecurityGroup.name,
      priority: 100,
      direction: 'Inbound',
      access: 'Allow',
      protocol: 'Tcp',
      sourcePortRange: '*',
      destinationPortRange: '3000',
      sourceAddressPrefix: '*',
      destinationAddressPrefix: '*',
    });

    // Security rules for database
    new NetworkSecurityRule(this, 'db-postgres-rule', {
      name: 'allow-postgres',
      resourceGroupName: this.resourceGroup.name,
      networkSecurityGroupName: this.databaseSecurityGroup.name,
      priority: 100,
      direction: 'Inbound',
      access: 'Allow',
      protocol: 'Tcp',
      sourcePortRange: '*',
      destinationPortRange: '5432',
      sourceAddressPrefix: '*',
      destinationAddressPrefix: '*',
    });

    // Outputs
    new TerraformOutput(this, 'vnet-id', {
      value: this.vnet.id,
      description: 'The ID of the Virtual Network',
    });

    new TerraformOutput(this, 'resource-group-name', {
      value: this.resourceGroup.name,
      description: 'The name of the Resource Group',
    });
  }
} 