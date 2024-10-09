SERVERS=$1

cat <<HEADER_START
AWSTemplateFormatVersion: "2010-09-09"
Description: Factorio Spot Price Servers () via Docker / ECS
Parameters:

  ECSAMI:
    Description: AWS ECS AMI ID
    Type: AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>
    Default: /aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id

  FactorioImageTag:
    Type: String
    Description: "(Examples include latest, stable, 0.17, 0.17.33) Refer to tag descriptions available here: https://hub.docker.com/r/factoriotools/factorio/)"
    Default: latest

  InstanceType:
    Type: String
    Description: "m6a.large is a good cost effective instance, 2 VCPU and 8 GB of RAM with moderate network performance. Change at your discretion. https://aws.amazon.com/ec2/instance-types/."
    Default: m6a.large

  SpotPrice:
    Type: String
    Description: "An m3.medium shouldn't cost more than a cent per hour. Note: Leave this blank to use on-demand pricing."
    Default: "0.05"

  KeyPairName:
    Type: String
    Description: (Optional - An empty value disables this feature)
    Default: ''

  YourIp:
    Type: String
    Description: (Optional - An empty value disables this feature)
    Default: ''

  HostedZoneId:
    Type: String
    Description: (Optional - An empty value disables this feature) If you have a hosted zone in Route 53 and wish to set a DNS record whenever your Factorio instance starts, supply the hosted zone ID here.
    Default: ''

  EnableRcon:
    Type: String
    Description: Refer to https://hub.docker.com/r/factoriotools/factorio/ for further RCON configuration details. This parameter simply opens / closes the port on the security group.
    Default: false
    AllowedValues:
    - true
    - false

  UpdateModsOnStart:
    Type: String
    Description: Refer to https://hub.docker.com/r/factoriotools/factorio/ for further configuration details.
    Default: false
    AllowedValues:
    - true
    - false

HEADER_START

for i in $(seq 1 $SERVERS)
do
cat <<VARIABLE_PARAMETERS
  # ====================================================
  # ${i} - Server Specific Variables
  # ====================================================

  ServerState${i}:
    Type: String
    Description: "Running: A spot instance for Server ${i} will launch shortly after setting this parameter; your Factorio server should start within 5-10 minutes of changing this parameter (once UPDATE_IN_PROGRESS becomes UPDATE_COMPLETE). Stopped: Your spot instance (and thus Factorio container) will be terminated shortly after setting this parameter."
    Default: Running
    AllowedValues:
    - Running
    - Stopped

  RecordName${i}:
    Type: String
    Description: (Optional - An empty value disables this feature) If you have a hosted zone in Route 53 and wish to set a DNS record whenever your Factorio instance for server ${i} starts, supply the name of the record here (e.g. factorio.mydomain.com).
    Default: ''

VARIABLE_PARAMETERS
done

cat <<METADATA_START
Metadata:
  AWS::CloudFormation::Interface:
    ParameterGroups:
      - Label:
          default: Essential Configuration
        Parameters:
        - FactorioImageTag
        - InstanceType
        - SpotPrice
        - EnableRcon
        - UpdateModsOnStart
METADATA_START

for i in $(seq 1 $SERVERS)
do
cat <<ESSENTIAL_PARAMS
        - ServerState${i}
ESSENTIAL_PARAMS
done

cat <<METADATA_MID_1
      - Label:
          default: Remote Access (SSH) Configuration (Optional)
        Parameters:
        - KeyPairName
        - YourIp
      - Label:
          default: DNS Configuration (Optional)
        Parameters:
        - HostedZoneId
METADATA_MID_1

for i in $(seq 1 $SERVERS)
do
cat <<ESSENTIAL_PARAMS
        - RecordName${i}
ESSENTIAL_PARAMS
done

cat <<PARAMETER_LABELS_START
    ParameterLabels:
      FactorioImageTag:
        default: "Which version of Factorio do you want to launch?"
      InstanceType:
        default: "Which instance type? You must make sure this is available in your region! https://aws.amazon.com/ec2/pricing/on-demand/"
      SpotPrice:
        default: "Maximum spot price per hour? Leave blank to disable spot pricing."
      KeyPairName:
        default: "If you wish to access the instance via SSH, select a Key Pair to use. https://console.aws.amazon.com/ec2/v2/home?#KeyPairs:sort=keyName"
      YourIp:
        default: "If you wish to access the instance via SSH, provide your public IP address."
      HostedZoneId:
        default: "If you have a hosted zone in Route 53 and wish to update a DNS record whenever your Factorio instance starts, supply the hosted zone ID here."
      EnableRcon:
        default: "Do you wish to enable RCON?"
      UpdateModsOnStart:
        default: "Do you wish to update your mods on container start"
PARAMETER_LABELS_START

for i in $(seq 1 $SERVERS)
do
cat <<VAR_PARAMATER_LABEL
      ServerState${i}:
        default: "Update this parameter to shut down / start up your Factorio server ${i} as required to save on cost. Takes a few minutes to take effect."
      RecordName${i}:
        default: "If you have a hosted zone in Route 53 and wish to set a DNS record whenever your Factorio instance server ${i} starts, supply a record name here (e.g. factorio.mydomain.com)."
VAR_PARAMATER_LABEL
done

cat <<CONDITIONS_START
Conditions:
  KeyPairNameProvided: !Not [ !Equals [ !Ref KeyPairName, '' ] ]
  IpAddressProvided: !Not [ !Equals [ !Ref YourIp, '' ] ]
  SpotPriceProvided: !Not [ !Equals [ !Ref SpotPrice, '' ] ]
  DoEnableRcon: !Equals [ !Ref EnableRcon, 'true' ]
  DnsConfigEnabled: !Not [ !Equals [ !Ref HostedZoneId, '' ] ]
CONDITIONS_START

# You can't have more than 20 conditions in an or block
# Generate the condition
# condition="  DnsConfigEnabled: !And\n"
# condition+="  - !Not [!Equals [!Ref HostedZoneId, '']]\n"

# condition+="  - !Or\n"

# for i in $(seq 1 $SERVERS); do
#     condition+="    - !Not [!Equals [!Ref RecordName$i, '']]\n"
# done

# Output the condition
# echo -e "$condition"

cat <<MAPPINGS_SECTION

Mappings:
  ServerState:
    Running:
      DesiredCapacity: 1
    Stopped:
      DesiredCapacity: 0

MAPPINGS_SECTION

cat <<RESOURCES_START
Resources:

  # ====================================================
  # BASIC VPC
  # ====================================================

  Vpc:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.100.0.0/26
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags:
        - Key: Name
          Value: !Join
            - '-'
            - [!Ref 'AWS::StackName', 'vpc']

  SubnetA:
    Type: AWS::EC2::Subnet
    Properties:
      AvailabilityZone: !Select
      - 0
      - !GetAZs
        Ref: 'AWS::Region'
      CidrBlock: !Select [ 0, !Cidr [ 10.100.0.0/24, 2, 7 ] ]
      VpcId: !Ref Vpc

  SubnetB:
    Type: AWS::EC2::Subnet
    Properties:
      AvailabilityZone: !Select
      - 1
      - !GetAZs
        Ref: 'AWS::Region'
      CidrBlock: !Select [ 1, !Cidr [ 10.100.0.0/24, 2, 7 ] ]
      VpcId: !Ref Vpc

  SubnetARoute:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref RouteTable
      SubnetId: !Ref SubnetA

  SubnetBRoute:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref RouteTable
      SubnetId: !Ref SubnetB

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties: {}

  InternetGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      InternetGatewayId: !Ref InternetGateway
      VpcId: !Ref Vpc

  RouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref Vpc

  Route:
    Type: AWS::EC2::Route
    Properties:
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway
      RouteTableId: !Ref RouteTable

  # ====================================================
  # Common Resources
  # ====================================================

  InstanceRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
        - Effect: Allow
          Principal:
            Service:
            - ec2.amazonaws.com
          Action:
          - sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role
      Policies:
        - PolicyName: root
          PolicyDocument:
            Version: "2012-10-17"
            Statement:
              - Effect: "Allow"
                Action: "route53:*"
                Resource: "*"

  InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Roles:
        - !Ref InstanceRole

RESOURCES_START

for i in $(seq 1 $SERVERS)
do
cat <<PARAM_BLOCK
  # ====================================================
  # ${i} - EFS FOR PERSISTENT DATA
  # ====================================================

  Efs${i}:
    Type: AWS::EFS::FileSystem
    DeletionPolicy: Retain
    Properties:
      LifecyclePolicies:
      - TransitionToIA: AFTER_7_DAYS
      - TransitionToPrimaryStorageClass: AFTER_1_ACCESS
      FileSystemTags:
      - Key: Name
        Value: !Sub "\${AWS::StackName}-fs-${i}"

  Mount${i}A:
    Type: AWS::EFS::MountTarget
    Properties:
      FileSystemId: !Ref Efs${i}
      SecurityGroups:
      - !Ref EfsSg${i}
      SubnetId: !Ref SubnetA

  Mount${i}B:
    Type: AWS::EFS::MountTarget
    Properties:
      FileSystemId: !Ref Efs${i}
      SecurityGroups:
      - !Ref EfsSg${i}
      SubnetId: !Ref SubnetB

  EfsSg${i}:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub "\${AWS::StackName}-efs-${i}"
      GroupDescription: !Sub "\${AWS::StackName}-efs-${i}"
      SecurityGroupIngress:
      - FromPort: 2049
        ToPort: 2049
        IpProtocol: tcp
        SourceSecurityGroupId: !Ref Ec2Sg${i}
      VpcId: !Ref Vpc

  # ====================================================
  # INSTANCE CONFIG - ${1}
  # ====================================================

  Ec2Sg${i}:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub "\${AWS::StackName}-ec2-${i}"
      GroupDescription: !Sub "\${AWS::StackName}-ec2-${i}"
      SecurityGroupIngress:
      - !If
        - IpAddressProvided
        - FromPort: 22
          ToPort: 22
          IpProtocol: tcp
          CidrIp: !Sub "\${YourIp}/32"
        - !Ref 'AWS::NoValue'
      - FromPort: 34197
        ToPort: 34197
        IpProtocol: udp
        CidrIp: 0.0.0.0/0
      - !If
        - DoEnableRcon
        - FromPort: 27015
          ToPort: 27015
          IpProtocol: tcp
          CidrIp: 0.0.0.0/0
        - !Ref 'AWS::NoValue'
      VpcId: !Ref Vpc

  LaunchConfiguration${i}:
    Type: AWS::AutoScaling::LaunchConfiguration
    Properties:
      AssociatePublicIpAddress: true
      IamInstanceProfile: !Ref InstanceProfile
      ImageId: !Ref ECSAMI
      InstanceType: !Ref InstanceType
      KeyName:
        !If [ KeyPairNameProvided, !Ref KeyPairName, !Ref 'AWS::NoValue' ]
      SecurityGroups:
      - !Ref Ec2Sg${i}
      SpotPrice: !If [ SpotPriceProvided, !Ref SpotPrice, !Ref 'AWS::NoValue' ]
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash -xe
          echo ECS_CLUSTER=\${EcsCluster${i}} >> /etc/ecs/ecs.config

  AutoScalingGroup${i}:
    Type: AWS::AutoScaling::AutoScalingGroup
    Properties:
      AutoScalingGroupName: !Sub "\${AWS::StackName}-asg-${i}"
      DesiredCapacity: !FindInMap [ ServerState, !Ref ServerState${i}, DesiredCapacity ]
      LaunchConfigurationName: !Ref LaunchConfiguration${i}
      MaxSize: !FindInMap [ ServerState, !Ref ServerState${i}, DesiredCapacity ]
      MinSize: !FindInMap [ ServerState, !Ref ServerState${i}, DesiredCapacity ]
      VPCZoneIdentifier:
        - !Ref SubnetA
        - !Ref SubnetB

  EcsCluster${i}:
    Type: AWS::ECS::Cluster
    Properties:
      ClusterName: !Sub "${AWS::StackName}-cluster-${i}"

  EcsService${i}:
    Type: AWS::ECS::Service
    Properties:
      Cluster: !Ref EcsCluster${i}
      DesiredCount: !FindInMap [ ServerState, !Ref ServerState${i}, DesiredCapacity ]
      ServiceName: !Sub "\${AWS::StackName}-ecs-service-${i}"
      TaskDefinition: !Ref EcsTask${i}
      DeploymentConfiguration:
        MaximumPercent: 100
        MinimumHealthyPercent: 0

  EcsTask${i}:
    Type: AWS::ECS::TaskDefinition
    DependsOn:
    - Mount${i}A
    - Mount${i}B
    Properties:
      Volumes:
      - Name: !Sub "\${AWS::StackName}-factorio-${i}"
        EFSVolumeConfiguration:
          FilesystemId: !Ref Efs${i}
          TransitEncryption: ENABLED
      ContainerDefinitions:
        - Name: factorio
          MemoryReservation: 1024
          Image: !Sub "factoriotools/factorio:\${FactorioImageTag}"
          PortMappings:
          - ContainerPort: 34197
            HostPort: 34197
            Protocol: udp
          - ContainerPort: 27015
            HostPort: 27015
            Protocol: tcp
          MountPoints:
          - ContainerPath: /factorio
            SourceVolume: factorio
            ReadOnly: false
          Environment:
          - Name: UPDATE_MODS_ON_START
            Value: !Sub "\${UpdateModsOnStart}"

PARAM_BLOCK
done

cat <<DNS_START
  # ====================================================
  # SET DNS RECORD - For all ASGs and EC2 instances
  # ====================================================

  SetDNSRecordLambdaRole:
    Type: AWS::IAM::Role
    Condition: DnsConfigEnabled
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
        - Effect: Allow
          Principal:
            Service:
            - lambda.amazonaws.com
          Action:
          - sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: root
          PolicyDocument:
            Version: "2012-10-17"
            Statement:
              - Effect: "Allow"
                Action: "route53:*"
                Resource: "*"
              - Effect: "Allow"
                Action: "ec2:DescribeInstance*"
                Resource: "*"

  SetDNSRecordLambda:
    Type: "AWS::Lambda::Function"
    Condition: DnsConfigEnabled
    Properties:
      Environment:
        Variables:
          HostedZoneId: !Ref HostedZoneId
          ASGRecordMap: !Join [",", [
DNS_START

for i in $(seq 1 $SERVERS)
do
cat <<MAPPING_ASGS_TO_RECORD_NAMES
            !Sub "\${AutoScalingGroup${i}}:\${RecordName${i}}",
MAPPING_ASGS_TO_RECORD_NAMES

done

cat <<DNS_MID_1
          ]]
      Code:
        ZipFile: |
          import boto3
          import os

          def handler(event, context):
            asg_name = event['detail']['AutoScalingGroupName']

            # Parse the ASG to record name mapping
            asg_record_map = dict(item.split(':') for item in os.environ['ASGRecordMap'].split(','))

            # Get the record name for the current ASG
            record_name = asg_record_map.get(asg_name)
            if not record_name:
              raise ValueError(f"No record name mapping found for ASG: {asg_name}")

            new_instance = boto3.resource('ec2').Instance(event['detail']['EC2InstanceId'])
            boto3.client('route53').change_resource_record_sets(
              HostedZoneId= os.environ['HostedZoneId'],
              ChangeBatch={
                  'Comment': f'Updating DNS for {asg_name}',
                  'Changes': [
                      {
                          'Action': 'UPSERT',
                          'ResourceRecordSet': {
                              'Name': record_name,
                              'Type': 'A',
                              'TTL': 60,
                              'ResourceRecords': [
                                  {
                                      'Value': new_instance.public_ip_address
                                  },
                              ]
                          }
                      },
                  ]
              })
      Description: Sets Route 53 DNS Record based on ASG name
      FunctionName: !Sub "${AWS::StackName}-set-dns"
      Handler: index.handler
      MemorySize: 128
      Role: !GetAtt SetDNSRecordLambdaRole.Arn
      Runtime: python3.12
      Timeout: 20

  LaunchEvent:
    Type: AWS::Events::Rule
    Condition: DnsConfigEnabled
    Properties:
      EventPattern:
        source:
        - aws.autoscaling
        detail-type:
        - EC2 Instance Launch Successful
        detail:
          AutoScalingGroupName:
DNS_MID_1

for i in $(seq 1 $SERVERS)
do
cat <<MAPPING_ASGS_TO_RECORD_NAMES
          - !Ref AutoScalingGroup${i}
MAPPING_ASGS_TO_RECORD_NAMES

done

cat <<DNS_END
      Name: !Sub "${AWS::StackName}-instance-launch"
      State: ENABLED
      Targets:
        - Arn: !GetAtt SetDNSRecordLambda.Arn
          Id: !Sub "${AWS::StackName}-set-dns"

  LaunchEventLambdaPermission:
    Type: AWS::Lambda::Permission
    Condition: DnsConfigEnabled
    Properties:
      Action: lambda:InvokeFunction
      FunctionName: !GetAtt SetDNSRecordLambda.Arn
      Principal: events.amazonaws.com
      SourceArn: !GetAtt LaunchEvent.Arn
DNS_END