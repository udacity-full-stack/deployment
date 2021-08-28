FROM python:stretch

RUN pip install --upgrade pip

WORKDIR /app

COPY ./requirements.txt .

RUN pip install -r requirements.txt

COPY ./app .

ENTRYPOINT ["gunicorn", "-b", ":8080", "main:APP"]