FROM python:3.12.0b3-alpine3.18

WORKDIR /application
COPY app.py requirements.txt ./
COPY templates/ ./templates/
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --upgrade pip
EXPOSE 5000
CMD ["python", "app.py"]
