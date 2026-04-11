# Create a dedicated network for our containers to talk to each other
docker network create trackaccess_network 2>$null

# 1. Start the Database Container
docker run -d `
  --name trackaccess_db `
  --network trackaccess_network `
  -e MYSQL_DATABASE=trackaccessdb `
  -e MYSQL_ROOT_PASSWORD=password123 `
  -p 3307:3306 `
  -v "${PWD}/init.sql:/docker-entrypoint-initdb.d/init.sql" `
  -v trackaccess_db_data:/var/lib/mysql `
  mysql:8.0

# 2. Build and Start the Application Container
docker build -t trackaccess_app_image:latest .
docker run -d `
  --name trackaccess_app `
  --network trackaccess_network `
  -e DB_HOST=trackaccess_db `
  -e DB_NAME=trackaccessdb `
  -e DB_USER=root `
  -e DB_PASS=password123 `
  -p 8080:80 `
  -v "${PWD}:/var/www/html" `
  trackaccess_app_image:latest

# 3. Start the phpMyAdmin Container
docker run -d `
  --name trackaccess_pma `
  --network trackaccess_network `
  -e PMA_HOST=trackaccess_db `
  -e PMA_PORT=3306 `
  -e PMA_ARBITRARY=1 `
  -p 8001:80 `
  phpmyadmin/phpmyadmin

Write-Host "`nAll containers started as standalone rows!" -ForegroundColor Green
Write-Host "Check Docker Desktop to see the Container ID, Image, and Ports." -ForegroundColor Cyan
