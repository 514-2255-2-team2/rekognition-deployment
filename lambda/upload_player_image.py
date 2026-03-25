import json
import os
import re
import uuid

import boto3

TABLE_NAME = os.environ.get("TABLE_NAME", "Players")
BUCKET_NAME = os.environ.get("BUCKET_NAME", "athlete-photos-team2")
PUT_EXPIRES = int(os.environ.get("PRESIGN_PUT_EXPIRES", "900"))

# Maps Content-Type to file suffix for the S3 key
ALLOWED_TYPES = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}

ddb = boto3.resource("dynamodb")
s3 = boto3.client("s3")

# so the react page can call this from anywhere
CORS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "content-type",
    "Access-Control-Allow-Methods": "OPTIONS,POST,GET",
}


def safe_key_segment(s):
    s = str(s or "").strip()
    if not s:
        return ""
    return re.sub(r"[^a-zA-Z0-9_.-]+", "_", s)[:200] or "unknown"


def lambda_handler(event, context):
    try:
        m = (event.get("requestContext") or {}).get("http") or {}
        if m.get("method") == "OPTIONS":
            return {"statusCode": 204, "headers": CORS, "body": ""}

        data = {}
        body = event.get("body")
        if body:
            data = json.loads(body) if isinstance(body, str) else body
        elif event:
            data = event

        pid = str(data.get("player_id") or "").strip()
        if not pid:
            return {"statusCode": 400, "headers": CORS, "body": json.dumps({"error": "need player_id"})}

        content_type = (data.get("content_type") or "image/jpeg").strip().lower()
        if content_type not in ALLOWED_TYPES:
            return {
                "statusCode": 400,
                "headers": CORS,
                "body": json.dumps({"error": "unsupported content_type", "allowed": list(ALLOWED_TYPES.keys())}),
            }

        table = ddb.Table(TABLE_NAME)
        got = table.get_item(Key={"player_id": pid})
        if "Item" not in got:
            return {"statusCode": 404, "headers": CORS, "body": json.dumps({"error": "player not found"})}

        ext = ALLOWED_TYPES[content_type]
        key = f"players/{safe_key_segment(pid)}/{uuid.uuid4().hex}{ext}"

        url = s3.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": BUCKET_NAME,
                "Key": key,
                "ContentType": content_type,
            },
            ExpiresIn=PUT_EXPIRES,
            HttpMethod="PUT",
        )

        # New photo: point DynamoDB at this key and drop face fields so indexer can re-run
        table.update_item(
            Key={"player_id": pid},
            UpdateExpression="SET s3_key = :k REMOVE face_id, face_collection",
            ExpressionAttributeValues={":k": key},
        )

        return {
            "statusCode": 200,
            "headers": CORS,
            "body": json.dumps(
                {
                    "upload_url": url,
                    "bucket": BUCKET_NAME,
                    "key": key,
                    "content_type": content_type,
                    "expires_in": PUT_EXPIRES,
                }
            ),
        }
    except Exception as e:
        return {"statusCode": 500, "headers": CORS, "body": json.dumps({"error": str(e)})}
