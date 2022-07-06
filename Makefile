main:
	clear
	sudo docker build -t test-arch-deploy -f Dockerfile .
	sudo docker run --rm -it --entrypoint bash test-arch-deploy
	sudo docker rmi test-arch-deploy -f
