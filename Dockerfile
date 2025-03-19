# syntax=docker/dockerfile:1.0.0-experimental
FROM instructure/rvm

ENV LANG C.UTF-8
ENV GIT_SSH_COMMAND='ssh -i "$SSH_KEY_PATH" -l $SSH_USER_NAME -o StrictHostKeyChecking=no'

USER root

ARG USER_ID
RUN if [ -n "$USER_ID" ]; then usermod -u "${USER_ID}" docker \
        && find / -xdev -user ${USER_ID} -exec chown -h docker {} \; ; fi

RUN apt-get update \
  && apt-get install -y \
  git

USER docker

COPY --chown=docker:docker Gemfile Gemfile.lock gergich.gemspec /usr/src/app/
COPY --chown=docker:docker exe/* /usr/src/app/exe/
RUN mkdir -p coverage

RUN bash -lc "rvm 2.7 do gem install bundler -v 2.4.22"

RUN /bin/bash -lc "cd /usr/src/app && rvm 2.7 do bundle install --jobs 5"
COPY --chown=docker:docker . /usr/src/app

CMD /bin/bash -lc "rvm-exec 2.7 bin/run_tests.sh"
