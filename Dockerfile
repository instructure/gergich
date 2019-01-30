FROM instructure/ruby:2.4-xenial

ENV LANG C.UTF-8
ENV APP_HOME /usr/src/app

COPY --chown=docker:docker Gemfile gergich.gemspec $APP_HOME/

RUN bundle install --jobs 8

COPY --chown=docker:docker . $APP_HOME

CMD ["bin/run_tests.sh"]
