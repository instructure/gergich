FROM instructure/ruby:2.1

# Add Gemnasium toolbelt
USER root
RUN echo "deb http://apt.gemnasium.com stable main" > /etc/apt/sources.list.d/gemnasium.list \
 && apt-key adv --recv-keys --keyserver keyserver.ubuntu.com E5CEAB0AC5F1CA2A \
 && apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends gemnasium-toolbelt \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV LANG C.UTF-8
WORKDIR /app
ADD . /app

RUN bundle install --retry=3
CMD bin/run_tests.sh
