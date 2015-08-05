#! /bin/sh
echo "running $0 $@"

# Convert all property keys to lowercase and store to tmp file to be sourced.
sed 's/.*=/\L&/' /vagrant/project.properties > /tmp/mlvagrant.project.properties

# Run the installers.
sudo /opt/vagrant/restore-yum-cache.sh
sudo /opt/vagrant/install-ml-centos.sh $2
sudo /opt/vagrant/setup-ml-master.sh $1 $2 $3
if [ -z "$5" ]; then
	sudo /opt/vagrant/install-node.sh
	sudo /opt/vagrant/install-mlcp.sh $2	
	sudo /opt/vagrant/install-user.sh $4
	sudo /opt/vagrant/setup-git.sh $4
	sudo /opt/vagrant/setup-tomcat.sh
fi
sudo /opt/vagrant/backup-yum-cache.sh
