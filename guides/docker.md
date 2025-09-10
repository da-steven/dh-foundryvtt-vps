
## List containers
```bash
docker ps -a
```

## Stop a container
```bash
docker stop foundryvtt-v13
```

## Start a container
```bash
docker start foundryvtt-v13
```

# Troubleshooting
## See what error is causing the restart loop
docker logs foundryvtt-v13

## Get more detailed logs
docker logs --tail 50 foundryvtt-v13

## Rebuild and start
cd /opt/FoundryVTT/foundry-v13
docker-compose down
docker-compose up -d

## Test
docker logs foundryvtt-v13

## Run a command in the a container
docker exec foundryvtt-v13 ls /data/Data/assets/
