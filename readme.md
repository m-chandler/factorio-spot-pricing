# Complete Factorio Server Deployment (CloudFormation)

The template contained within this repository can be used to deploy a Factorio server to Amazon Web Services (AWS) in minutes. As the solution leverages "Spot Pricing", the server should cost less than a cent an hour to run, and you can even turn it off when you and your friends aren't playing - saving even more money.

## Prerequisites

1. A basic understanding of Amazon Web Services, specifically CloudFormation.
2. An AWS Account.
3. Basic knowledge of Linux administration (no more than what would be required to just use the dtandersen Docker images).

## Overview

The solution builds upon the Docker images so generously curated by dtandersen https://hub.docker.com/r/dtandersen/factorio/ (thank you!). 

In a nutshell, the CloudFormation template launches an _ephemeral_ instance which joins itself to an Elastic Container Service (ECS) Cluster. Within this ECS Cluster, an ECS Service is configured to run a dtandersen Factorio Docker image. The ephemeral instance does not store any saves, mods, Factorio config, data etc. - all of this state is stored on a network file system (Elastic File System - EFS).

The CloudFormation template is configured to launch this ephemeral instance using spot pricing. What is spot pricing you might ask? It's a way to save up to 90% on regular "on demand" pricing in AWS. There are drawbacks however. You're effectively participating in an auction to get a cheap instance. If demand increases and someone else puts in a higher bid than you, your instance will terminate in a matter of minutes. 

A few notes on the services we're using...

* **EFS** - Elastic File System is used to store Factorio config, save games, mods etc. None of this is stored on the server itself, as it may terminate at any time.
* **Auto Scaling** - An Auto Scaling Group is used to maintain a single instance via spot pricing.
* **VPC** - The template deploys a very basic VPC, purely for use by the Factorio server. This doesn't cost you a cent.

## Getting Started

[![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=factorio&templateURL=https://s3.amazonaws.com/factorio-spot-pricing/cf.yml)

1. Click the above link, you'll need to log into your AWS account if you haven't already.
2. Ensure you've selected a suitable AWS Region (closest to you) via the selector at the top right.
3. Click Next to proceed through the CloudFormation deployment, provide parameters on the following page. You'll need a Key Pair and your Public IP address if you want to access the instance remotely via SSH (recommended). Refer to the Remote Access section below. There should be no need to touch any other parameters unless you have reason to do so. Continue through the rest of the deployment. 

## Next Steps

All things going well, your Factorio server should be running in five minutes or so. Wait until CloudFormation reports the stack status as `CREATE_COMPLETE`. Go to the [EC2 dashboard in the AWS console](https://console.aws.amazon.com/ec2/v2/home?#Instances:sort=instanceId) and you should see a Factorio server running. Take note of the public IP address. You should be able to fire up Factorio, and join via this IP address. No need to provide a port number, we're using Factorio's default. *Bonus points* - Public IP addresses are ugly. Refer to Custom Domain Name within Optional Features for a better solution. 

At this point you should *really* configure remote access as per the below section, so that you can access the server and modify `server-settings.json` (e.g. add a password, add to the Factorio server browser, whitelist admins etc.).

## Optional Features

### Remote Access

If you know what you're doing, you might want to SSH onto the Linux instance to see what's going on / debug / make improvements. For security, SSH should be locked down to a known IP address (i.e. you), preventing malicious users from trying to break in (or worse - succeeeding). You'll need to create a Key Pair in AWS, find your public IP address, and then provide both of the parameters in the Remote Access (SSH) Configuration (Optional) section.

For remote access, you'll need to:

1. Create a [Key Pair](https://console.aws.amazon.com/ec2/v2/home#KeyPairs:sort=keyName) (Services > EC2 > Key Pairs). You'll need to use this to connect to the instance for additional setup.
2. [Find your public IP address]((https://whatismyipaddress.com/)). You'll need this to connect to the instance for additional setup.

If you're creating a new Factorio deployment, provide these parameters when creating the stack. Otherwise, update your existing stack and provide these parameters.

### Custom Domain Name

Every time your Factorio server starts it'll have a new public IP address. This can be a pain to keep dishing out to your friends. If you're prepared to register a domain name (maybe you've already got one) and create a Route 53 hosted zone, this problem is easily fixed. You'll need to provide both of the parameters under the DNS Configuration (Optional) section. Whenever your instance is launched, a Lambda function fires off and creates / updates the record of your choosing. This way, you can have a custom domain name such as "factorio.mydomain.com". Note that it may take a few minutes for the new IP to propagate to your friends computers. Have patience. Failing that just go to the EC2 console, and give them the new public IP address of your instance.

## FAQ

**Do I need a VPC, or Subnets, or other networking config in AWS?** 

Nope. The stack creates everything you need.

**What if my server is terminated due to my Spot Request being outbid?** 

Everything is stored on EFS, so don't worry you won't lose anything (well, that's partially true - you might lose up to 5 minutes of gameplay depending on when the server last saved). There is every chance your instance will come back in a few minutes. If not you can either select a different instance type, increase your spot price, or completely disable spot pricing and revert to on demand pricing. All of these options can be performed by updating your CloudFormation stack parameters.

**My server keeps getting terminated. I don't like Spot Pricing. Take me back to the good old days.** 

That's fine; update your CloudFormation stack and set the SpotPrice parameter to an empty value. Voila, you'll now be using On Demand pricing (and paying significantly more).

**How do I change my instance type?** 

Update your CloudFormation stack. Enter a different instance type.

**How do I change my spot price limit?** 

Update your CloudFormation stack. Enter a different limit. 

**I'm done for the night / week / month / year. How do I turn off my Factorio server?** 

Update your CloudFormation stack. Change the server state parameter from "Running" to "Stopped".

**I'm done with Factorio, how do I delete this server?** 

Delete the CloudFormation stack. Done.

**How can I upgrade the Factorio version?** 

Update your CloudFormation stack. Set the required tag value for `FactorioImageTag`. Use the tags specified here: https://hub.docker.com/r/dtandersen/factorio/. Your Factorio server will stop momentarily.

**I'm running the "latest" version, and a new version has just been released. How do I update my server?** 

You can force a redeployment of the service via ECS. [Update the service](https://console.aws.amazon.com/ecs/home?#/clusters/factorio/services/factorio/update), and select `Force new deployment`. 

**How can I change map settings, server settings etc.** 

You'll need to have remote access to the server (refer to Optional Features). You can make whatever changes you want to the configuration in `/opt/factorio/config`. Once done, restart the container using the following command: `sudo docker restart $(docker ps -q --filter name=ecs-factorio)`.

**I can no longer connect to my instance via SSH?** 

Your public IP address has probably changed. [Check your public IP address]((https://whatismyipaddress.com/)) and update the stack, providing your new public IP address.

## What's Missing / Not Supported?

* Scenarios.

## Expected Costs

The two key components that will attract charges are:

* **EC2** - If you're using spot pricing (and the m3.medium instance as per the default in the template), I doubt you would attract more than a cent an hour in fees for EC2. Even if you ran it 24 hours a day for a whole month, that's about 7 bucks.
* **EFS** - Charged per Gigabyte stored per month (GB-Month). Varies based on region, but typically less than 50c per gigabyte. My EFS file system for Factorio is only about 100MB (incl. mods and 5 saves), so maybe 5 cents per month?

AWS do charge for data egress (i.e. data being sent from your Factorio server to clients), but again this should be barely noticeable.

## Help / Support

This has been tested in both the Sydney and Oregon AWS regions. Your mileage may vary. If you get stuck, create an issue and myself or someone else may come along and assist.

Be sure to check out dtandersen's repo. Unless your question is specifically related to the AWS deployment, you may find the information you're after there: https://hub.docker.com/r/dtandersen/factorio/.

## Thanks

Thanks goes out to dtandersen (and contributors) for maintaining the Factorio docker images. 