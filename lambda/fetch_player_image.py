import json
import os

import boto3

from urllib.parse import urlparse

TABLE_NAME = os.environ.get("TABLE_NAME", "Players")
BUCKET_NAME = os.environ.get("BUCKET_NAME", "athlete-photos-team2")
GET_EXPIRES = int(os.environ.get("PRESIGN_GET_EXPIRES", "300"))

ddb = boto3.resource("dynamodb")
s3 = boto3.client("s3")

# so the react page can call this from anywhere
CORS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "content-type",
    "Access-Control-Allow-Methods": "OPTIONS,POST,GET",
}


def parse_s3_uri(s3_uri):
    p = urlparse(s3_uri or "")
    if p.scheme != "s3" or not p.netloc or not p.path:
        raise ValueError("bad s3 uri")
    return p.netloc, p.path.lstrip("/")


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

        table = ddb.Table(TABLE_NAME)
        got = table.get_item(Key={"player_id": pid})
        item = got.get("Item")
        if not item:
            return {"statusCode": 404, "headers": CORS, "body": json.dumps({"error": "player not found"})}

        if item.get("s3_key"):
            bucket, key = BUCKET_NAME, item["s3_key"]
        elif item.get("s3_url"):
            try:
                bucket, key = parse_s3_uri(item["s3_url"])
            except ValueError:
                return {"statusCode": 400, "headers": CORS, "body": json.dumps({"error": "bad s3_url on record"})}
        else:
            return {"statusCode": 404, "headers": CORS, "body": json.dumps({"error": "no image for player"})}

        url = s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": bucket, "Key": key},
            ExpiresIn=GET_EXPIRES,
        )

        return {
            "statusCode": 200,
            "headers": CORS,
            "body": json.dumps(
                {
                    "image_url": url,
                    "bucket": bucket,
                    "key": key,
                    "expires_in": GET_EXPIRES,
                }
            ),
        }
    except Exception as e:
        return {"statusCode": 500, "headers": CORS, "body": json.dumps({"error": str(e)})}
