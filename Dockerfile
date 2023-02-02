FROM instructure/rvm

ENV LANG C.UTF-8

COPY --chown=docker:docker Gemfile Gemfile.lock gergich.gemspec /usr/src/app/
COPY --chown=docker:docker exe/* /usr/src/app/exe/
RUN mkdir -p coverage

RUN bash -lc "rvm 2.6,2.7 do gem install bundler -v 2.2.27"

RUN /bin/bash -lc "cd /usr/src/app && rvm 2.6,2.7 do bundle install --jobs 5"
COPY --chown=docker:docker . /usr/src/app

CMD /bin/bash -lc "rvm-exec 2.6 bin/run_tests.sh"
