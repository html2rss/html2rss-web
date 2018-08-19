FROM ruby:2.5-stretch

LABEL maintainer="Gil Desmarais <html2rss-web-docker@desmarais.de>"

EXPOSE 3000

ENV PORT=3000
ENV RACK_ENV=production

RUN mkdir /app
WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN gem install --no-ri --no-rdoc bundler rake
RUN bundle config --global frozen 1
RUN bundle install --binstubs --retry=5 --jobs=7 --without development test

COPY . .

CMD bundle exec foreman start
