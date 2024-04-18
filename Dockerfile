FROM buildpack-deps:buster
LABEL authors="Alex W<alex@blinkenlights.ca>"

## set ENV for python
ENV PYTHON_VERSION=3.11.7
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=utf-8
ENV LANG C.UTF-8
ENV PYTHONPATH=/workspace/src/
# "Activate" the venv manually for the context of the container
ENV VIRTUAL_ENV=/workspace/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
# Keep the poetry venv name and location predictable
ENV POETRY_VIRTUALENVS_IN_PROJECT=true
ENV APP_HOME=/workspace

# Install python
RUN cd /usr/src \
    && wget https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz \
    && tar -xzf Python-$PYTHON_VERSION.tgz \
    && cd Python-$PYTHON_VERSION \
    && ./configure --enable-optimizations \
    && make install \
    && ldconfig \
    && rm -rf /usr/src/Python-$PYTHON_VERSION.tgz /usr/src/Python-$PYTHON_VERSION \
    && update-alternatives --install /usr/bin/python python /usr/local/bin/python3 1

# Install poetry
RUN pip3 install --no-cache-dir poetry==1.6.1

WORKDIR /workspace

# Copy dependency files to avoid cache invalidations
COPY pyproject.toml poetry.lock ./

# Install dependencies
RUN poetry install

# Copy the rest of the code
COPY src/backend src/backend

COPY docker_scripts/ ${APP_HOME}/
COPY docker_scripts/entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

# Install nodejs
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get install -y nodejs
RUN npm install -g pnpm
# pm2 to start frontend
RUN npm install -g pm2

# ENV for frontend
ENV NEXT_PUBLIC_API_HOSTNAME="http://localhost:8000"
ENV PYTHON_INTERPRETER_URL="http://localhost:8080"

# Install frontend dependencies
WORKDIR /workspace/src/frontend
COPY src/frontend/src ./src
COPY src/frontend/public ./public
COPY src/frontend/next.config.mjs .
COPY src/frontend/tsconfig.json .
COPY src/frontend/package.json src/frontend/yarn.lock* src/frontend/package-lock.json* src/frontend/pnpm-lock.yaml* ./

RUN pnpm install

EXPOSE 9000/tcp
EXPOSE 3000/tcp
WORKDIR ${APP_HOME}

CMD ["/sbin/entrypoint.sh"]