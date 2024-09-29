#!/bin/bash

mkdir -p ./tmp/

cat > ./tmp/tomcat-users.xml << "EOF"
<?xml version='1.0' encoding='utf-8'?>
<tomcat-users>
  <role rolename="readonly-user"/>
  <role rolename="read-write-user"/>
  <user username="readuser1" password="read456" roles="readonly-user"/>
  <user username="testuser1" password="testuser123" roles="read-write-user"/>
</tomcat-users>
EOF

cat > ./tmp/setenv.sh << "EOF"
   JAVA_OPTS="$JAVA_OPTS -XX:MaxPermSize=512m -Xmx2048m -Xms512m -server -Drdeck.base=/opt/rundeck/ -Dserver.servlet.context-path=/rundeck -Dserver.servlet.session.timeout=1800  -Drundeck.config.location=/opt/rundeck/server/config/rundeck-config.properties -Drundeck.server.logDir=/opt/rundeck/server/logs"
EOF


cat > ./tmp/context.xml << "EOF" 
<Resource name="jdbc/rundeckdb" auth="Container" type="javax.sql.DataSource"
               maxActive="100" maxIdle="30" maxWait="10000"
               username="rundeckuser" password="rundeckpassword" driverClassName="org.mariadb.jdbc.Driver"
               url="jdbc:mariadb://mysql.rundeck.local:3306/rundeck"/>
EOF

cat > ./tmp/init.sh << EOF
#!/bin/bash
java -Drdeck.base=/opt/rundeck -jar /var/lib/tomcat9/webapps/rundeck.war --installonly
sed -i 's/^\(grails\.serverURL\s*=\s*\).*$/\1http:\/\/localhost:8080\/rundeck/' /opt/rundeck/server/config/rundeck-config.properties
sed -i 's/^\(server\.address\s*=\s*\).*$/\10.0.0.0/' /opt/rundeck/server/config/rundeck-config.properties
echo "server.servlet.context-path=/rundeck" >> /opt/rundeck/server/config/rundeck-config.properties

/usr/share/tomcat9/bin/catalina.sh run
/bin/bash
EOF

cat > Dockerfile_training_tomcat << EOF
FROM ubuntu:20.04

MAINTAINER ggroppo@gmail.com
RUN apt-get -qqy update && \
    apt-get -qqy install vim tomcat9 tomcat9-admin tomcat9-examples tomcat9-docs
EXPOSE 8080
#doing some fixes, due the defaults installation doesn't generate a runnable tomcat.
RUN mkdir -p /usr/share/tomcat9/logs/
RUN mkdir -p /usr/share/tomcat9/webapps/
RUN ln -s /var/lib/tomcat9/conf /usr/share/tomcat9/conf
RUN ln -s /usr/share/tomcat9-examples/examples /var/lib/tomcat9/webapps/examples
RUN ln -s /usr/share/tomcat9-docs/docs /var/lib/tomcat9/webapps/docs
RUN ln -s /usr/share/tomcat9-admin/manager /var/lib/tomcat9/webapps/manager
RUN ln -s /usr/share/tomcat9-admin/host-manager /var/lib/tomcat9/webapps/host-manager
RUN rm -rf /usr/share/tomcat9/webapps
RUN ln -s /var/lib/tomcat9/webapps/ /usr/share/tomcat9/
COPY ./tmp/init.sh /opt/rundeck/
RUN chmod 777 /opt/rundeck/init.sh 
COPY ./tmp/setenv.sh /usr/share/tomcat9/bin/
RUN chmod 777 /usr/share/tomcat9/bin/setenv.sh
COPY rundeckpro.war /var/lib/tomcat9/webapps/ 
RUN mv /var/lib/tomcat9/webapps/rundeckpro.war /var/lib/tomcat9/webapps/rundeck.war
COPY ./tmp/tomcat-users.xml /var/lib/tomcat9/conf/
RUN chown root.tomcat /var/lib/tomcat9/conf/tomcat-users.xml
EXPOSE 8080
ENTRYPOINT /opt/rundeck/init.sh
#ENTRYPOINT /bin/bash
EOF

docker build -f Dockerfile_training_tomcat -t ubuntu-training_tomcat .
docker run -it -p 8080:8080 ubuntu-training_tomcat
