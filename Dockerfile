From ubuntu:14.04

RUN \
	apt-get update -yqq && \
	apt-get install git-core build-essential zlib1g-dev -y && \
	apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN git clone https://github.com/ktsaou/netdata.git

WORKDIR /opt/netdata

EXPOSE 19999

CMD ["./netdata.start", "-ch", "/host"]

#ENTRYPOINT ["./netdata.start"]
