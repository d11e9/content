FROM dockerfile/nodejs

RUN sudo apt-get -y update
RUN sudo apt-get -y install redis-tools

RUN mkdir -p /var/app
WORKDIR /var/app

COPY ./package.json /var/app/

ENV VIRTUAL_HOST content.datagotchi.com
ENV VIRTUAL_PORT 8082
EXPOSE 8082
EXPOSE 4001

RUN npm install -g go-ipfs
RUN ipfs init
# RUN npm install

COPY ./ /var/app/

CMD [ "npm", "run", "app" ]
