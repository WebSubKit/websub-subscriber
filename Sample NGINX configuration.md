### NGINX configuration for path based routing

WebSubSubscriber will be accessible from http://your.domain.here/websub

```
upstream websub {
  server 127.0.0.1:8080;
}

server {
  server_name your.domain.here; # Replace your.domain.here with your actual domain
  location /websub/ { # Note the slashes surrounding the location
    proxy_pass http://websub/; # Note the slash at the end proxy_pass
  }
}
```


### NGINX configuration for domain based routing

WebSubSubscriber will be accessible from http://your.domain.here

```
upstream websub {
  server 127.0.0.1:8080;
}

server {
  server_name your.domain.here; # Replace your.domain.here with your actual domain
  location / { # Note the only slash on the location
    proxy_pass http://websub/; # Note the slash at the end proxy_pass
  }
}
```
