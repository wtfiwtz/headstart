import { Construct } from 'constructs';
import { TerraformStack, TerraformOutput } from 'cdktf';
import { AwsProvider } from '@cdktf/provider-aws/lib/provider';
import { CloudwatchMetricAlarm } from '@cdktf/provider-aws/lib/cloudwatch-metric-alarm';
import { CloudwatchDashboard } from '@cdktf/provider-aws/lib/cloudwatch-dashboard';
import { SnsTopicSubscription } from '@cdktf/provider-aws/lib/sns-topic-subscription';
import { SnsTopic } from '@cdktf/provider-aws/lib/sns-topic';
import { EcsCluster } from '@cdktf/provider-aws/lib/ecs-cluster';
import { DbInstance } from '@cdktf/provider-aws/lib/db-instance';
import { Lb } from '@cdktf/provider-aws/lib/lb';
import { MonitoringConfig } from '../config';

export interface MonitoringStackProps {
  environment: string;
  config: MonitoringConfig;
  resources: {
    database: DbInstance;
    application: EcsCluster;
    loadBalancer: Lb;
  };
}

export class MonitoringStack extends TerraformStack {
  constructor(scope: Construct, id: string, props: MonitoringStackProps) {
    super(scope, id);

    // Define AWS provider
    new AwsProvider(this, 'aws', {
      region: process.env.AWS_REGION || 'us-east-1',
    });

    // Create SNS topic for alarms
    const alarmTopic = new SnsTopic(this, 'alarm-topic', {
      name: `${props.environment}-alarms`,
      tags: {
        Environment: props.environment,
      },
    });

    // Subscribe email to SNS topic
    new SnsTopicSubscription(this, 'alarm-email-subscription', {
      topicArn: alarmTopic.arn,
      protocol: 'email',
      endpoint: props.config.alarmEmail,
    });

    if (props.config.enableAlarms) {
      // Create CPU utilization alarm for the application
      new CloudwatchMetricAlarm(this, 'app-cpu-alarm', {
        alarmName: `${props.environment}-app-cpu-high`,
        comparisonOperator: 'GreaterThanThreshold',
        evaluationPeriods: 2,
        metricName: 'CPUUtilization',
        namespace: 'AWS/ECS',
        period: 300,
        statistic: 'Average',
        threshold: 80,
        alarmDescription: 'This metric monitors ECS CPU utilization',
        dimensions: {
          ClusterName: props.resources.application.name,
          ServiceName: `${props.environment}-app-service`,
        },
        alarmActions: [alarmTopic.arn],
        okActions: [alarmTopic.arn],
        tags: {
          Environment: props.environment,
        },
      });

      // Create memory utilization alarm for the application
      new CloudwatchMetricAlarm(this, 'app-memory-alarm', {
        alarmName: `${props.environment}-app-memory-high`,
        comparisonOperator: 'GreaterThanThreshold',
        evaluationPeriods: 2,
        metricName: 'MemoryUtilization',
        namespace: 'AWS/ECS',
        period: 300,
        statistic: 'Average',
        threshold: 80,
        alarmDescription: 'This metric monitors ECS memory utilization',
        dimensions: {
          ClusterName: props.resources.application.name,
          ServiceName: `${props.environment}-app-service`,
        },
        alarmActions: [alarmTopic.arn],
        okActions: [alarmTopic.arn],
        tags: {
          Environment: props.environment,
        },
      });

      // Create database CPU utilization alarm
      new CloudwatchMetricAlarm(this, 'db-cpu-alarm', {
        alarmName: `${props.environment}-db-cpu-high`,
        comparisonOperator: 'GreaterThanThreshold',
        evaluationPeriods: 2,
        metricName: 'CPUUtilization',
        namespace: 'AWS/RDS',
        period: 300,
        statistic: 'Average',
        threshold: 80,
        alarmDescription: 'This metric monitors RDS CPU utilization',
        dimensions: {
          DBInstanceIdentifier: props.resources.database.id,
        },
        alarmActions: [alarmTopic.arn],
        okActions: [alarmTopic.arn],
        tags: {
          Environment: props.environment,
        },
      });

      // Create database free storage space alarm
      new CloudwatchMetricAlarm(this, 'db-storage-alarm', {
        alarmName: `${props.environment}-db-storage-low`,
        comparisonOperator: 'LessThanThreshold',
        evaluationPeriods: 2,
        metricName: 'FreeStorageSpace',
        namespace: 'AWS/RDS',
        period: 300,
        statistic: 'Average',
        threshold: 5000000000, // 5GB in bytes
        alarmDescription: 'This metric monitors RDS free storage space',
        dimensions: {
          DBInstanceIdentifier: props.resources.database.id,
        },
        alarmActions: [alarmTopic.arn],
        okActions: [alarmTopic.arn],
        tags: {
          Environment: props.environment,
        },
      });

      // Create load balancer 5XX error rate alarm
      new CloudwatchMetricAlarm(this, 'lb-5xx-alarm', {
        alarmName: `${props.environment}-lb-5xx-high`,
        comparisonOperator: 'GreaterThanThreshold',
        evaluationPeriods: 2,
        metricName: 'HTTPCode_ELB_5XX_Count',
        namespace: 'AWS/ApplicationELB',
        period: 300,
        statistic: 'Sum',
        threshold: 10,
        alarmDescription: 'This metric monitors load balancer 5XX errors',
        dimensions: {
          LoadBalancer: props.resources.loadBalancer.arnSuffix,
        },
        alarmActions: [alarmTopic.arn],
        okActions: [alarmTopic.arn],
        tags: {
          Environment: props.environment,
        },
      });
    }

    if (props.config.enableDashboard) {
      // Create CloudWatch dashboard
      new CloudwatchDashboard(this, 'app-dashboard', {
        dashboardName: `${props.environment}-app-dashboard`,
        dashboardBody: JSON.stringify({
          widgets: [
            {
              type: 'metric',
              x: 0,
              y: 0,
              width: 12,
              height: 6,
              properties: {
                metrics: [
                  ['AWS/ECS', 'CPUUtilization', 'ClusterName', props.resources.application.name, 'ServiceName', `${props.environment}-app-service`],
                ],
                period: 300,
                stat: 'Average',
                region: process.env.AWS_REGION || 'us-east-1',
                title: 'ECS CPU Utilization',
              },
            },
            {
              type: 'metric',
              x: 12,
              y: 0,
              width: 12,
              height: 6,
              properties: {
                metrics: [
                  ['AWS/ECS', 'MemoryUtilization', 'ClusterName', props.resources.application.name, 'ServiceName', `${props.environment}-app-service`],
                ],
                period: 300,
                stat: 'Average',
                region: process.env.AWS_REGION || 'us-east-1',
                title: 'ECS Memory Utilization',
              },
            },
            {
              type: 'metric',
              x: 0,
              y: 6,
              width: 12,
              height: 6,
              properties: {
                metrics: [
                  ['AWS/RDS', 'CPUUtilization', 'DBInstanceIdentifier', props.resources.database.id],
                ],
                period: 300,
                stat: 'Average',
                region: process.env.AWS_REGION || 'us-east-1',
                title: 'RDS CPU Utilization',
              },
            },
            {
              type: 'metric',
              x: 12,
              y: 6,
              width: 12,
              height: 6,
              properties: {
                metrics: [
                  ['AWS/RDS', 'FreeStorageSpace', 'DBInstanceIdentifier', props.resources.database.id],
                ],
                period: 300,
                stat: 'Average',
                region: process.env.AWS_REGION || 'us-east-1',
                title: 'RDS Free Storage Space',
              },
            },
            {
              type: 'metric',
              x: 0,
              y: 12,
              width: 12,
              height: 6,
              properties: {
                metrics: [
                  ['AWS/ApplicationELB', 'RequestCount', 'LoadBalancer', props.resources.loadBalancer.arnSuffix],
                ],
                period: 300,
                stat: 'Sum',
                region: process.env.AWS_REGION || 'us-east-1',
                title: 'ALB Request Count',
              },
            },
            {
              type: 'metric',
              x: 12,
              y: 12,
              width: 12,
              height: 6,
              properties: {
                metrics: [
                  ['AWS/ApplicationELB', 'HTTPCode_ELB_5XX_Count', 'LoadBalancer', props.resources.loadBalancer.arnSuffix],
                  ['AWS/ApplicationELB', 'HTTPCode_ELB_4XX_Count', 'LoadBalancer', props.resources.loadBalancer.arnSuffix],
                ],
                period: 300,
                stat: 'Sum',
                region: process.env.AWS_REGION || 'us-east-1',
                title: 'ALB Error Codes',
              },
            },
          ],
        }),
      });
    }

    // Outputs
    new TerraformOutput(this, 'alarm-topic-arn', {
      value: alarmTopic.arn,
      description: 'The ARN of the SNS topic for alarms',
    });
  }
} 