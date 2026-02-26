/**
 * API: загрузка файла в MinIO (Pigsty).
 * Требуется S3_ENDPOINT, S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY, S3_PUBLIC_URL в окружении.
 * Опционально: ?bucket=gd-lounge-assets — переопределить бакет (нужны права у того же пользователя).
 */

import { NextRequest, NextResponse } from 'next/server';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

const endpoint = process.env.S3_ENDPOINT;
const accessKey = process.env.S3_ACCESS_KEY;
const secretKey = process.env.S3_SECRET_KEY;
const defaultBucket = process.env.S3_BUCKET;
const publicBase = process.env.S3_PUBLIC_URL;

const s3 =
  endpoint && accessKey && secretKey
    ? new S3Client({
        region: 'us-east-1',
        endpoint,
        forcePathStyle: true,
        credentials: { accessKeyId: accessKey, secretAccessKey: secretKey },
      })
    : null;

export async function POST(req: NextRequest) {
  if (!s3 || !defaultBucket || !publicBase) {
    return NextResponse.json(
      { error: 'S3 not configured (S3_ENDPOINT, S3_BUCKET, S3_ACCESS_KEY, S3_SECRET_KEY, S3_PUBLIC_URL)' },
      { status: 503 }
    );
  }
  const formData = await req.formData();
  const file = formData.get('file') as File | null;
  if (!file) {
    return NextResponse.json({ error: 'No file' }, { status: 400 });
  }
  const bucket = req.nextUrl.searchParams.get('bucket') || defaultBucket;
  const key = `${Date.now()}-${file.name.replace(/[^a-zA-Z0-9.-]/g, '_')}`;

  try {
    await s3.send(
      new PutObjectCommand({
        Bucket: bucket,
        Key: key,
        Body: Buffer.from(await file.arrayBuffer()),
        ContentType: file.type || 'application/octet-stream',
      })
    );
  } catch (e) {
    console.error(e);
    return NextResponse.json(
      { error: 'Upload failed', details: String((e as Error).message) },
      { status: 500 }
    );
  }

  const base = publicBase || (endpoint + '/' + bucket);
  const fileUrl = base.replace(/\/$/, '') + '/' + key;
  return NextResponse.json({ fileUrl });
}
