FROM ubuntu:20.04
RUN apt-get update -y && apt-get install -y python3-pip python-dev mariadb-client-core-10.3 wget curl && rm -rf /var/lib/apt/lists/*
RUN wget https://downloads.mariadb.com/MariaDB/mariadb_repo_setup && chmod +x mariadb_repo_setup && ./mariadb_repo_setup --mariadb-server-version="mariadb-10.5"
RUN apt-get update -y && apt-get install -y libmariadb3 libmariadb-dev python3-psycopg2 && rm -rf /var/lib/apt/lists/*
COPY ./app /app/
COPY ./app/static /app/static/
COPY ./app/templates /app/templates/
COPY ./requirements.txt /app/
RUN pip install -r /app/requirements.txt
ARG VAR1
ARG VAR2
ARG VAR3
ENV DB_ADMIN_USERNAME=$VAR1
ENV DB_ADMIN_PASSWORD=$VAR2
ENV DB_URL=$VAR3
WORKDIR /app/
CMD ["uwsgi", "--ini", "uwsgi.ini"]

# docker build -t TAG --build-arg VAR1=$DB_ADMIN_USERNAME --build-arg VAR2=$DB_ADMIN_PASSWORD --build-arg VAR3=$DB_URL .
