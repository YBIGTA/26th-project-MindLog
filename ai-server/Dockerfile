# 1️⃣ Base image (Python 3.10)
FROM python:3.10

# 2️⃣ System dependencies (for OpenCV)
RUN pip install --upgrade pip

RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 && \
    rm -rf /var/lib/apt/lists/*

# 3️⃣ Disable GPU (force CPU execution)
ENV CUDA_VISIBLE_DEVICES="-1"

# 4️⃣ Working directory
WORKDIR /app

# 5️⃣ Environment variables
ENV PYTHONPATH="/app"

# 6️⃣ Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 7️⃣ DeepFace cache directory
RUN mkdir -p /root/.deepface/weights

# 8️⃣ Copy app code only
COPY app ./app

# 9️⃣ Start FastAPI server
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001", "--reload"]
