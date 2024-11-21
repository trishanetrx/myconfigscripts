# SELinux PostgreSQL Policies
rm -rf /sys/fs/selinux/booleans/postgresql_*

# Firewalld PostgreSQL Configuration
rm -f /usr/lib/firewalld/services/postgresql.xml

# Python PostgreSQL Modules
rm -rf /usr/lib/python2*/site-packages/postgresql
rm -rf /usr/lib64/az/lib/python3.6/site-packages/azure/cli/command_modules/rdbms/postgres

# PAM PostgreSQL Module
rm -f /usr/lib64/security/pam_postgresql.so

# Documentation and Miscellaneous
rm -f /usr/share/doc/pam-1.1.8/txts/README.pam_postgresql
rm -f /usr/share/man/man8/pam_postgresok.8.gz
