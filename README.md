# docker-pull简介

* 使用curl下载hub.docker.com镜像的每一层和层信息，再通过skopeo工具将镜像load到本地docker下面。
* 主要解决下载hub.docker.com镜像太大时，因为出现网络波动导致下载失败后，需要重新全部下载，没有使用缓存的问题
* 当前只支持拉取latest 的tag镜像

# 环境依赖
* yq

# 使用

1.比如在hub.docker.com上需要拉取的镜像是

```sh
docker pull alpine:latest
```

则脚本调用方式为

```sh
bash retry.sh alpine
```

2.下载完后镜像的blob都在当前tmp目录下

3.使用skopeo加载镜像到本地docker

```sh
skopeo copy dir:tmp/ docker-daemon:alpine:latest
```

# 效果


