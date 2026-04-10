FROM mariadb:11.8

RUN \
  apt-get update; \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends wget tzdata; \
  rm -rf /var/lib/apt/lists/*;
RUN \
  wget http://mysqltuner.pl/ -O /usr/local/bin/mysqltuner.pl; \
  chmod a+x /usr/local/bin/mysqltuner.pl ; \
  wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/basic_passwords.txt -O /usr/local/bin/basic_passwords.txt; \
  wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/vulnerabilities.csv -O /usr/local/bin/vulnerabilities.csv;
# Increment buffer pool of InnoDB to recomended value for tuner
RUN { \
  echo '[mariadb]\ntransaction-isolation = READ-COMMITTED'; \
  echo innodb_buffer_pool_size = 1G; \
  echo innodb_log_file_size = 256M; \
  echo table_definition_cache=600; \
  echo performance_schema=ON; \
  } > /etc/mysql/my.cnf
