docker stop trackaccess_app trackaccess_db trackaccess_pma 2>$null
docker rm trackaccess_app trackaccess_db trackaccess_pma 2>$null
docker network rm trackaccess_network 2>$null

Write-Host "Standalone containers stopped and removed." -ForegroundColor Yellow
