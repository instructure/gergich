FROM instructure/ruby:2.2

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

COPY Gemfile gergich.gemspec /app/
RUN chown -R docker:docker /app

USER docker
RUN bundle install --jobs 8
USER root

COPY . /app
RUN mkdir -p /app/coverage && chown -R docker:docker /app

USER docker
CMD ["bin/run_tests.sh"]
