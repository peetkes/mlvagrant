#! /bin/sh
echo "running $0 $@"

# Install tomcat6
if [ -d /vagrant ]; then
  yum -y install tomcat6
  
  chkconfig --levels 2345 tomcat6 on
  
  service tomcat6 start
else
  # tomcat 6 pre-installed on demo servers
  chkconfig --levels 2345 tomcat6 on
  
  service tomcat6 start
fi

echo "Note: consider running Tomcat behind a firewall if you intend to keep it open!"
