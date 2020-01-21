FROM instructure/rvm

ENV LANG C.UTF-8

COPY --chown=docker:docker Gemfile gergich.gemspec /usr/src/app/
RUN mkdir -p coverage

RUN /bin/bash -lc "cd /usr/src/app && rvm 2.4,2.5,2.6 do bundle install --jobs 5"
COPY --chown=docker:docker . /usr/src/app

CMD /bin/bash -lc "rvm-exec 2.6 bin/run_tests.sh"
