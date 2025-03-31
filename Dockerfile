FROM ruby:3.3-slim

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libpq-dev \
    nodejs \
    git \
    curl \
    postgresql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile, gemspec, and version for bundle install
COPY Gemfile Gemfile.lock administrate.gemspec ./
COPY lib/administrate/version.rb ./lib/administrate/

# Install gems
RUN gem install bundler
RUN bundle install


# Copy the rest of the application
COPY . .

# Set the entrypoint script as executable
COPY docker-entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["bundle", "exec", "rspec"]