From ubuntu:14.04

# TODO remove lsof (only required during development stage)
# TODO remove use of git clone, use curl to get a tarball and unzip it.
RUN \
	apt-get update -y && \
	apt-get install git-core lsof curl build-essential zlib1g-dev -y && \
	apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

ENV APT_REFRESHED_AT 2015-10-18.1
RUN git clone https://github.com/ktsaou/netdata.git

WORKDIR /opt/netdata

EXPOSE 19999

CMD ["./netdata.start", "-ch", "/host"]

#ENTRYPOINT ["./netdata.start"]
