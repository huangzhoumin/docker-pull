#!/bin/bash
# set -x
# 
# name=library/alpine
# name=rocm/pytorch:rocm6.2_ubuntu20.04_py3.9_pytorch_release_2.3.0
name=$1
if [ "$name" = "" ];then
  echo "[ERROR] no input docker name"
  exit 1
fi
# name=nginx
# 获取身份验证令牌

function get_token(){
  data=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${name}:pull" )
  TOKEN=$(echo $data| yq  '.token')
  if [ "${TOKEN}" = "" -o "${TOKEN}" = "null" ];then
    echo "[ERROR] token is null"
    exit 1
  fi
  echo $TOKEN > ./cache_token
  echo $TOKEN
}

TOKEN=
if [ -f ./cache_token ];then
  TOKEN=$(cat ./cache_token)
else
  TOKEN=$(get_token)
fi

if [ "$TOKEN" = "" ];then
  echo "[ERROR] MANIFEST1 get failed"
  exit 1
fi

# 获取镜像清单
MANIFEST=$(curl -X GET -H "Authorization: Bearer $TOKEN" \
-H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
"https://registry-1.docker.io/v2/${name}/manifests/latest")
if [ $? -ne 0 ];then
  get_token
  echo "[ERROR] MANIFEST1 get failed"
  exit 1
fi

echo "MANIFEST = ${MANIFEST}"
code=$(echo $MANIFEST|yq '.errors[0].code'||true)
if [ "${code}" = "UNAUTHORIZED" ];then
  get_token
  echo "[ERROR] MANIFEST2 get failed"
  exit 1
fi

echo $MANIFEST > tmp/manifest.json

# 解析镜像层的下载链接
length1=$(echo $MANIFEST | yq '.layers|length')
echo "[INFO] length1 = $length1"
index=0
while [[ $index -lt $length1 ]]
do
  LAYER_DIGEST=$(echo $MANIFEST | yq ".layers[$index].digest"|awk -F ":" '{print $2}')
  size=$(echo $MANIFEST | yq ".layers[$index].size")
  if [ -f tmp/$LAYER_DIGEST ];then
    echo "[INFO]exist $LAYER_DIGEST blob"
    size_=$(du -b tmp/$LAYER_DIGEST|awk '{print $1}')
    if [[ $size -eq $size_ ]];then
      echo "[INFO]continue download $LAYER_DIGEST blob"
      index=$((index+1))
      continue
    fi
  fi

  if [ "$LAYER_DIGEST" = "" -o "$LAYER_DIGEST" = "null" ];then
    echo "[ERROR] LAYER_DIGEST of $LAYER_DIGEST get failed"
    exit 1
  fi
  # 下载镜像层
  curl -X GET -L -H "Authorization: Bearer $TOKEN" -o tmp/$LAYER_DIGEST "https://registry-1.docker.io/v2/${name}/blobs/sha256:$LAYER_DIGEST"
  if [ $? -ne 0 ];then
    echo "[ERROR] $LAYER_DIGEST get failed"
    exit 1
  fi
  # 直接就是blob的镜像层了，只需要重命名为sha256的名字即可
  echo "镜像层已下载到 tmp/$LAYER_DIGEST"
  index=$((index+1))
done
# 下载 config字段下的layer层，比如：
# "config": {
#       "mediaType": "application/vnd.docker.container.image.v1+json",
#       "size": 1471,
#       "digest": "sha256:91ef0af61f39ece4d6710e465df5ed6ca12112358344fd51ae6a3b886634148b"
#    }
config_size=$(echo $MANIFEST | yq '.config.size')
config_digest=$(echo $MANIFEST | yq '.config.digest'|awk -F ":" '{print $2}')
if [ "$config_size" = "" -o "$config_size" = "null" ];then
  echo "[ERROR] config_size is empty or null"
  exit 1
fi
if [ "$config_digest" = "" -o "$config_digest" = "null" ];then
  echo "[ERROR] config_digest is empty or null"
  exit 1
fi

if [ -f tmp/$config_digest ];then
  echo "[INFO]exist $config_digest blob"
  size_=$(du -b tmp/$config_digest|awk '{print $1}')
  if [[ $sconfig_size -eq $size_ ]];then
    echo "[INFO]continue download $config_digest blob"
  fi
else
  # 下载镜像层
  curl -X GET -L -H "Authorization: Bearer $TOKEN" -o tmp/$config_digest "https://registry-1.docker.io/v2/${name}/blobs/sha256:$config_digest"
  if [ $? -ne 0 ];then
    echo "[ERROR] $config_digest get failed"
    exit 1
  fi
fi

echo "Directory Transport Version: 1.1" > tmp/version

# 通过目录加载镜像的命令：
#skopeo copy dir:tmp/ docker-daemon:alpine:latest

