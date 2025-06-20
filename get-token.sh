#!/bin/bash
CLIENT_ID=istio
USERNAME=admin
PASSWORD=admin
REALM=quarkus-demo
AUTH_URL="http://localhost:8080/realms/$REALM/protocol/openid-connect/token"

curl -s -X POST \
  -d "client_id=$CLIENT_ID" \
  -d "username=$USERNAME" \
  -d "password=$PASSWORD" \
  -d "grant_type=password" \
  "$AUTH_URL" | jq -r .access_token