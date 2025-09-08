from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import qrcode
import boto3
import os
from io import BytesIO
import re
import traceback
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = FastAPI()

# Allow CORS for local testing
origins = [
    "http://localhost:3000"
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

# AWS S3 Configuration
s3 = boto3.client(
    's3',
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY"),
    aws_secret_access_key=os.getenv("AWS_SECRET_KEY"),
    region_name='eu-north-1'  # Stockholm
)

bucket_name = 'devops-ammar'  # Your bucket name

@app.post("/generate-qr/")
async def generate_qr(url: str):
    try:
        print("Generating QR for URL:", url)

        # Generate QR Code
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(url)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")

        # Save local copy for testing
        safe_local_name = re.sub(r'[^a-zA-Z0-9_-]', '_', url.split('//')[-1])
        local_file_path = f"qr_codes_local/{safe_local_name}.png"
        os.makedirs("qr_codes_local", exist_ok=True)
        img.save(local_file_path)
        print(f"Saved local QR code: {local_file_path}")

        # Save QR Code to BytesIO object for S3 upload
        img_byte_arr = BytesIO()
        img.save(img_byte_arr, format='PNG')
        img_byte_arr.seek(0)

        # Sanitize filename for S3
        safe_s3_name = re.sub(r'[^a-zA-Z0-9_-]', '_', url.split('//')[-1])
        s3_file_name = f"qr_codes/{safe_s3_name}.png"
        print("Uploading to S3 with key:", s3_file_name)

        # Upload to S3
        s3.put_object(
            Bucket=bucket_name,
            Key=s3_file_name,
            Body=img_byte_arr,
            ContentType='image/png',
            ACL='public-read'
        )

        # Generate S3 URL
        s3_url = f"https://{bucket_name}.s3.{s3.meta.region_name}.amazonaws.com/{s3_file_name}"
        print("Upload successful. URL:", s3_url)
        return {"qr_code_url": s3_url}

    except Exception as e:
        print("S3 upload or QR generation failed:")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
