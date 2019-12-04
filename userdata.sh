                                                                    #! /bin/bash
# agent configuration

curl -v --location rabi --connect-timeout 5 --retry 3 --output installer.sh
sed -i -e 's/\r$//' installer.sh
chmod +x installer.sh
./installer.sh
/opt/aws/bin/cfn-signal -e 0 -r \"DataBrokerInstance setup complete\"
yum install -y nmap-ncat\n"/h1>" | sudo tee /var/www/html/index.html