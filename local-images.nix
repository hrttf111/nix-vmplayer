{ mkDerivation, nginx, gnused }:
let
  port = "8000";
  serverConfigTemplate = ''
worker_processes  1;

error_log   @@NGINX_DIR@@/error.log;
pid         @@NGINX_DIR@@/nginx.pid;
daemon off;

events {
    worker_connections  1024;
}

http {
    default_type  application/octet-stream;

    access_log  /dev/null;
    error_log /dev/null;

    sendfile        on;
    keepalive_timeout  65;

    client_body_temp_path @@NGINX_DIR@@;
    proxy_temp_path @@NGINX_DIR@@;
    fastcgi_temp_path @@NGINX_DIR@@;
    uwsgi_temp_path @@NGINX_DIR@@;
    scgi_temp_path @@NGINX_DIR@@;
    proxy_store off;

    server {
        listen       ${port};
        listen  [::]:${port};
        server_name  localhost;

        location / {
            root   @@DATA_DIR@@;
        }
    }
}
  '';
  defaultDataDir="/opt/sandbox/public";
in
  mkDerivation {
    pname = "vmplayer-nginx-server";
    version = "1.0";
    dontUnpack = true;

    installPhase = ''
      mkdir -p $out/{bin,share}
      echo "${serverConfigTemplate}" > $out/share/nginx.conf.template

      cat >> $out/bin/run-nginx <<- EOM
          DATA_DIR=\$1
          if [ -z "\$DATA_DIR" ]; then
            DATA_DIR=${defaultDataDir}
          fi
          TEMP_DIR=\$(mktemp -d)
          trap '{ rm -rf -- "\$TEMP_DIR"; }' EXIT
          CONFIG=\$TEMP_DIR/nginx.conf
          cp $out/share/nginx.conf.template \$CONFIG
          ${gnused}/bin/sed -i "s,@@NGINX_DIR@@,\$TEMP_DIR," "\$CONFIG"
          ${gnused}/bin/sed -i "s,@@DATA_DIR@@,\$DATA_DIR," "\$CONFIG"
          ${nginx}/bin/nginx -c \$CONFIG
      EOM
      chmod +x $out/bin/run-nginx
    '';
  }
