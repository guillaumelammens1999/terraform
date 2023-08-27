
#!/bin/bash

# Update packages
yum update -y

# Install necessary packages
yum install -y amazon-efs-utils httpd mysql 
amazon-linux-extras enable php7.4 -y
yum install -y php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap}

# Download wp-cli
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# Create directories
mkdir -p /var/www/html
mkdir -p /var/www/shared-wp-content3

# Mount EFS
EFS_ID="fs-05eea4f50fc460d0b"
mount -t efs -o tls "${EFS_ID}":/ /var/www/shared-wp-content3

# Configure the Database
DB_NAME="gisneke"
DB_USER="admin"
DB_PASSWORD="adminadmin"
DB_HOST="database-1.cocomvutku44.eu-central-1.rds.amazonaws.com"
DB_USER2="tester3"
DB_EXISTS=$(mysql -h ${DB_HOST} -u ${DB_USER} -p${DB_PASSWORD} -e "SHOW DATABASES LIKE '${DB_NAME}';" | grep ${DB_NAME})

if [ -z "$DB_EXISTS" ]; then
    mysql -h ${DB_HOST} -u ${DB_USER} -p${DB_PASSWORD} -e "CREATE DATABASE ${DB_NAME}; CREATE USER '${DB_USER2}'@'%' IDENTIFIED BY '${DB_PASSWORD}'; GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER2}'@'%'; FLUSH PRIVILEGES;"
fi

# Install WordPress
cd /var/www/html/
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* .
rm -f latest.tar.gz
rmdir wordpress

# Handle wp-content directory
if [ ! "$(ls -A /var/www/shared-wp-content3)" ]; then
    mv /var/www/html/wp-content/* /var/www/shared-wp-content3/
else
    echo "Shared wp-content directory is not empty. Not moving local files."
fi
rm -rf /var/www/html/wp-content
ln -s /var/www/shared-wp-content3 /var/www/html/wp-content

# Update WordPress configuration
cp wp-config-sample.php wp-config.php
WP_CONFIG="/var/www/html/wp-config.php"
sed -i "s/database_name_here/${DB_NAME}/g" $WP_CONFIG
sed -i "s/username_here/${DB_USER}/g" $WP_CONFIG
sed -i "s/password_here/${DB_PASSWORD}/g" $WP_CONFIG
sed -i "s/localhost/${DB_HOST}/g" $WP_CONFIG
sed -i "/\/\* That's all, stop editing! Happy publishing. \*\//i\\
define('SCRIPT_DEBUG', true);\\
define('FORCE_SSL_ADMIN', true);\\
define('WP_SITEURL', 'https://bappende.link');\\
define('WP_HOME', 'https://bappende.link');\\
if (strpos(\$_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false) {\\
    \$_SERVER['HTTPS'] = 'on';\\
} else {\\
    \$_SERVER['HTTPS'] = 'off';\\
}\
" $WP_CONFIG

# Configure Apache for WordPress
cat <<EOL >> /etc/httpd/conf.d/wordpress.conf
<VirtualHost *:80>
    ServerName bappende.link
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        AllowOverride All
    </Directory>

    ErrorLog /var/log/httpd/wordpress_error.log
    CustomLog /var/log/httpd/wordpress_access.log combined
</VirtualHost>
EOL

# Permalink fix
wp rewrite structure '/%postname%/' --hard
wp rewrite flush --hard

# Check and create .htaccess if needed
if [ ! -f .htaccess ]; then
    cat <<EOL > .htaccess
    # BEGIN WordPress
    <IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /
    RewriteRule ^index\.php$ - [L]
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule . /index.php [L]
    </IfModule>
    # END WordPress
EOL
    chown apache:apache .htaccess
    chmod 644 .htaccess
else
    echo ".htaccess file already exists. Skipping creation."
fi

# Set permissions
chown -R apache:apache /var/www/html
chmod 755 /var/www/html
chown -R apache:apache /var/www/shared-wp-content3
chmod 755 /var/www/shared-wp-content3
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;
find /var/www/shared-wp-content3 -type d -exec chmod 755 {} \;
find /var/www/shared-wp-content3 -type f -exec chmod 644 {} \;

# Restart Apache
systemctl restart httpd




### TEXT
#!/bin/bash

# Update packages
yum update -y

# Install necessary packages
yum install -y httpd
amazon-linux-extras enable php7.4 -y
yum install -y php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap}

# Download wp-cli
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# Create directory for WordPress
mkdir -p /var/www/html

# Install WordPress
cd /var/www/html/
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* .
rm -f latest.tar.gz
rmdir wordpress

# Set permissions
chown -R apache:apache /var/www/html
chmod 755 /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Restart Apache
systemctl restart httpd

<VirtualHost *:80>
    ServerName bappende.link
    ServerAlias www.bappende.link
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        AllowOverride All
    </Directory>

    # Force HTTPS
    RewriteEngine On
    RewriteCond %{HTTP:X-Forwarded-Proto} !https
    RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

    ErrorLog /var/log/httpd/wordpress_error.log
    CustomLog /var/log/httpd/wordpress_access.log combined
</VirtualHost>
EOL