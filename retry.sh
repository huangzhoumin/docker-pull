set -x
name=rocm/pytorch
mkdir -p ./tmp
while [ 1 = 1 ]
do
	echo "[INFO] begin pull image"
	bash docker_load.sh $name
	if [ $? -eq 0 ];then
		break
	fi
	echo "[INFO] pull failed, wait 5s"
	sleep 5
done
