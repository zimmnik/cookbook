docker rm -f kibana && docker build -t kibana . && docker run --name kibana -d -p 5601:5601 kibana && docker logs -f kibana
