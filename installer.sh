                      #!/bin/bash

mkdir -p /opt/netapp/databroker
cd /opt/netapp/databroker

# remove SSM agent
yum -y erase amazon-ssm-agent

# install node and npm
# Red Hat® Enterprise Linux® / RHEL, CentOS and Fedora
# https://nodejs.org/en/download/package-manager/#enterprise-linux-and-fedora
curl -v --location https://rpm.nodesource.com/setup_13.x --connect-timeout 5 --retry 3 | sudo -E bash -
yum -y install nodejs

# download data broker bundle
curl --silent --location ${dataBrokerBundleUrl} --connect-timeout 5 --retry 3 --output data-broker.zip
unzip -o data-broker.zip -d .
\rm -f data-broker.zip

cat <<EOT >> config/data-broker.json
{
    "data-broker-id": "${dataBrokerId}",
    "type": "${type}",
    "commandsQueue": "${commandsQueue}",
    "statusesQueue": "${statusesQueue}",
    "aws":{
        "s3": {
            "accessKeyId": "${s3AccessKeyId}",
            "secretAccessKey": "${s3SecretAccessKey}"
        },
        "sqs":{
            "accessKeyId": "${sqsAccessKeyId}",
            "secretAccessKey": "${sqsSecretAccessKey}"
        }
    }
}
EOT

npm i --production

# install PM2 globally
npm i pm2 -g

# start
sudo pm2 start app.js --name data-broker
sudo pm2 startup
sudo pm2 save
